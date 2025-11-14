#!/usr/bin/env python3
import json
import logging
import boto3
import asyncio
import threading
import queue
import websockets
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
from datetime import datetime
from amazon_transcribe.client import TranscribeStreamingClient
from amazon_transcribe.handlers import TranscriptResultStreamHandler
from amazon_transcribe.model import TranscriptEvent
from concurrent.futures import ThreadPoolExecutor

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# AWS 客户端
bedrock = boto3.client('bedrock-runtime')
executor = ThreadPoolExecutor(max_workers=3)  # 异步翻译线程池

class MyEventHandler(TranscriptResultStreamHandler):
    def __init__(self, output_stream, callback):
        super().__init__(output_stream)
        self.callback = callback

    async def handle_transcript_event(self, transcript_event: TranscriptEvent):
        logger.info(f"🔍 收到转录事件: {transcript_event}")
        
        # 检查事件类型和内容
        if hasattr(transcript_event, 'transcript') and transcript_event.transcript:
            results = transcript_event.transcript.results
            logger.info(f"📊 转录结果数量: {len(results)}")
            
            for i, result in enumerate(results):
                logger.info(f"📝 结果 {i}: is_partial={result.is_partial}, alternatives={len(result.alternatives)}")
                
                # 处理所有结果（部分和最终）
                for j, alt in enumerate(result.alternatives):
                    transcript = alt.transcript
                    confidence = getattr(alt, 'confidence', 'N/A')
                    language_code = getattr(result, 'language_code', 'Unknown')
                    result_type = "部分" if result.is_partial else "最终"
                    logger.info(f"🎯 {result_type}结果 {i}-{j}: '{transcript}' (语言: {language_code}, 长度: {len(transcript)}, 置信度: {confidence})")
                    
                    if transcript.strip():
                        # 标记是否为最终结果
                        self.callback(transcript, is_final=not result.is_partial)
                    else:
                        logger.info("⚠️ 转录结果为空")
        else:
            logger.info("⚠️ 转录事件没有transcript内容")
            logger.info(f"🔍 事件属性: {dir(transcript_event)}")

class VoiceHandler(BaseHTTPRequestHandler):
    # 全局变量存储转录状态
    transcribe_client = None
    audio_queue = None
    latest_transcript = ""
    streaming_active = False
    audio_file = None
    audio_counter = 0
    is_final_result = False
    # 翻译状态 - 完全模仿转录模式
    latest_translation = ""  # 当前翻译文本（对应latest_transcript）
    translation_is_final = False  # 翻译是否为最终结果（对应is_final_result）
    translation_cache = {}  # 缓存最终翻译结果 - 重置清空错误数据
    translation_language = "zh"  # 翻译目标语言：en=英文，zh=中文
    translation_model = "claude"  # 翻译模型：claude=Claude 3.5 Haiku, nova=Amazon Nova Lite
    final_translation_history = ""  # 翻译历史记录（对应finalTranscriptRef.current）
    
    def _set_cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
    
    def do_OPTIONS(self):
        self.send_response(200)
        self._set_cors_headers()
        self.end_headers()
    
    def do_GET(self):
        path = urlparse(self.path).path
        if path == '/connect':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self._set_cors_headers()
            self.end_headers()
            response = {'message': '🎤 AWS Transcribe Streaming 已连接', 'status': 'success'}
            self.wfile.write(json.dumps(response, ensure_ascii=False).encode('utf-8'))
        
        elif path == '/disconnect':
            self.stop_streaming()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self._set_cors_headers()
            self.end_headers()
            response = {'message': 'Disconnected', 'status': 'success'}
            self.wfile.write(json.dumps(response).encode())
        
        elif path == '/translation':
            # 返回最新的翻译结果
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self._set_cors_headers()
            self.end_headers()
            response = {
                'translation': VoiceHandler.latest_translation,
                'status': 'success'
            }
            self.wfile.write(json.dumps(response, ensure_ascii=False).encode('utf-8'))
        
        elif path == '/set_language':
            # 获取当前翻译语言
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self._set_cors_headers()
            self.end_headers()
            response = {
                'current_language': VoiceHandler.translation_language,
                'status': 'success'
            }
            self.wfile.write(json.dumps(response, ensure_ascii=False).encode('utf-8'))
        
        elif path == '/set_model':
            # 获取当前翻译模型
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self._set_cors_headers()
            self.end_headers()
            response = {
                'current_model': VoiceHandler.translation_model,
                'status': 'success'
            }
            self.wfile.write(json.dumps(response, ensure_ascii=False).encode('utf-8'))
        
        else:
            self.send_response(404)
            self.send_header('Content-Type', 'application/json')
            self._set_cors_headers()
            self.end_headers()
            response = {'error': f'Route not found: {path}'}
            self.wfile.write(json.dumps(response).encode())
    
    def do_POST(self):
        path = urlparse(self.path).path
        if path == '/audio':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            try:
                data = json.loads(post_data.decode())
                audio_data = data.get('data', [])
                
                logger.info(f"📥 接收音频流: {len(audio_data)} 字节")
                
                if len(audio_data) < 500:
                    response = {
                        'transcript': '🔇 音频数据太短',
                        'translation': 'Audio data too short',
                        'timestamp': datetime.now().isoformat(),
                        'status': 'success'
                    }
                else:
                    # 启动或继续流式转录
                    if not VoiceHandler.streaming_active:
                        self.start_streaming()
                    
                    # 添加音频到队列
                    if VoiceHandler.audio_queue:
                        pcm_data = self.convert_to_pcm(audio_data)
                        logger.info(f"🎵 转换PCM数据: {len(pcm_data)} 字节")
                        
                        # 保存PCM数据到文件 - 已禁用
                        # if VoiceHandler.audio_file:
                        #     VoiceHandler.audio_file.write(pcm_data)
                        #     VoiceHandler.audio_file.flush()
                        #     logger.info(f"💾 PCM数据已写入文件: {len(pcm_data)} 字节")
                        
                        VoiceHandler.audio_queue.put(pcm_data)
                        logger.info(f"📤 音频已加入队列，队列大小: {VoiceHandler.audio_queue.qsize()}")
                    else:
                        logger.warning("⚠️ 音频队列未初始化")
                    
                    # 返回最新转录结果
                    transcript = VoiceHandler.latest_transcript or "🎧 正在监听..."
                    is_final = VoiceHandler.is_final_result
                    
                    # 翻译逻辑：独立处理，不显示原文
                    translation = VoiceHandler.latest_translation or "Processing..."
                    translation_is_final = VoiceHandler.translation_is_final
                    
                    # 特殊情况处理
                    if transcript == "🎧 正在监听...":
                        translation = "Listening..."
                        translation_is_final = True
                    
                    logger.info(f"🔍 转录: '{transcript}' ({'最终' if is_final else '部分'}) -> 翻译: '{translation}' ({'最终' if translation_is_final else '部分'})")
                    logger.info(f"📋 翻译缓存: {list(VoiceHandler.translation_cache.keys())}")
                    logger.info(f"🎯 当前翻译状态: latest='{VoiceHandler.latest_translation}', is_final={VoiceHandler.translation_is_final}")
                    
                    response = {
                        'transcript': transcript,
                        'translation': translation,
                        'timestamp': datetime.now().isoformat(),
                        'status': 'success',
                        'is_final': is_final,  # 转录的最终状态
                        'translation_is_final': translation_is_final  # 翻译的最终状态
                    }
                    
                    # 移除翻译启动逻辑，因为翻译在转录回调中已经启动
                    
                    # 清空转录状态：只有最终结果才清空
                    if is_final and transcript != "🎧 正在监听...":
                        logger.info(f"🧹 清空转录状态: '{transcript}'")
                        VoiceHandler.latest_transcript = ""
                        VoiceHandler.is_final_result = False
                    
                    # 清空翻译状态：模仿转录逻辑
                    if (translation_is_final and 
                        translation not in ["Listening...", "Processing...", "Translating..."] and
                        translation != ""):
                        logger.info(f"🧹 清空翻译状态: '{translation}'")
                        VoiceHandler.latest_translation = ""
                        VoiceHandler.translation_is_final = False
                        VoiceHandler.final_translation_history = ""  # 同时清空翻译历史
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self._set_cors_headers()
                self.end_headers()
                self.wfile.write(json.dumps(response, ensure_ascii=False).encode('utf-8'))
                
            except Exception as e:
                logger.error(f"❌ 处理音频错误: {e}")
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self._set_cors_headers()
                self.end_headers()
                response = {'error': str(e), 'status': 'error'}
                self.wfile.write(json.dumps(response).encode())
        
        elif path == '/set_language':
            # 设置翻译语言
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            try:
                data = json.loads(post_data.decode())
                language = data.get('language', 'en')
                
                if language in ['en', 'zh', 'ja']:
                    VoiceHandler.translation_language = language
                    # 清空翻译缓存，因为语言改变了
                    VoiceHandler.translation_cache.clear()
                    VoiceHandler.latest_translation = ""
                    VoiceHandler.translation_is_final = False
                    VoiceHandler.final_translation_history = ""  # 清空翻译历史
                    
                    lang_name = {'en': '英文', 'zh': '中文', 'ja': '日语'}[language]
                    logger.info(f"🌐 翻译语言已切换为: {lang_name}")
                    
                    response = {
                        'current_language': language,
                        'message': f"翻译语言已切换为{lang_name}",
                        'status': 'success'
                    }
                else:
                    response = {
                        'error': '不支持的语言，仅支持 en、zh 或 ja',
                        'status': 'error'
                    }
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self._set_cors_headers()
                self.end_headers()
                self.wfile.write(json.dumps(response, ensure_ascii=False).encode('utf-8'))
                
            except Exception as e:
                logger.error(f"❌ 设置语言错误: {e}")
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self._set_cors_headers()
                self.end_headers()
                response = {'error': str(e), 'status': 'error'}
                self.wfile.write(json.dumps(response).encode())
        
        elif path == '/set_model':
            # 设置翻译模型
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            try:
                data = json.loads(post_data.decode())
                model = data.get('model', 'claude')
                
                if model in ['claude', 'nova']:
                    VoiceHandler.translation_model = model
                    # 清空翻译缓存，因为模型改变了
                    VoiceHandler.translation_cache.clear()
                    VoiceHandler.latest_translation = ""
                    VoiceHandler.translation_is_final = False
                    VoiceHandler.final_translation_history = ""  # 清空翻译历史
                    
                    model_name = {'claude': 'Claude 3.5 Haiku', 'nova': 'Amazon Nova Lite'}[model]
                    logger.info(f"🤖 翻译模型已切换为: {model_name}")
                    
                    response = {
                        'current_model': model,
                        'message': f"翻译模型已切换为{model_name}",
                        'status': 'success'
                    }
                else:
                    response = {
                        'error': '不支持的模型，仅支持 claude 或 nova',
                        'status': 'error'
                    }
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self._set_cors_headers()
                self.end_headers()
                self.wfile.write(json.dumps(response, ensure_ascii=False).encode('utf-8'))
                
            except Exception as e:
                logger.error(f"❌ 设置模型错误: {e}")
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self._set_cors_headers()
                self.end_headers()
                response = {'error': str(e), 'status': 'error'}
                self.wfile.write(json.dumps(response).encode())
    
    def convert_to_pcm(self, audio_data):
        """将音频数据转换为PCM格式"""
        logger.debug(f"🔧 原始音频数据长度: {len(audio_data)}")
        
        # 限制音频块大小，提高实时性
        max_samples = 1024  # 约64ms的音频 (16000Hz * 0.064s)
        if len(audio_data) > max_samples:
            audio_data = audio_data[:max_samples]
        
        # 分析音频数据
        if len(audio_data) > 0:
            max_val = max(abs(x) for x in audio_data)
            avg_val = sum(abs(x) for x in audio_data) / len(audio_data)
            logger.debug(f"🎵 音频分析: 最大值={max_val:.4f}, 平均值={avg_val:.4f}")
            
            # 检测数据格式并转换
            if max_val > 1.0:
                # 数据是0-255范围，需要转换为-1.0到1.0
                logger.info("🔄 检测到0-255格式，转换为浮点数...")
                audio_data = [(x - 128) / 128.0 for x in audio_data]
                max_val = max(abs(x) for x in audio_data)
                logger.info(f"🎵 转换后最大值: {max_val:.4f}")
            
            # 检查是否有足够的音频信号
            if max_val < 0.01:
                logger.warning("⚠️ 音频信号很弱，可能无法识别")
            elif max_val > 0.1:
                logger.info("✅ 音频信号强度良好")
        
        # 将浮点数组转换为16位PCM
        pcm_bytes = bytearray()
        for i in range(0, len(audio_data)):
            # 将浮点数(-1.0到1.0)转换为16位整数(-32768到32767)
            sample = int(audio_data[i] * 32767)
            # 限制范围
            sample = max(-32768, min(32767, sample))
            # 转换为小端序16位
            pcm_bytes.extend(sample.to_bytes(2, byteorder='little', signed=True))
        
        logger.info(f"🎵 PCM转换完成: {len(pcm_bytes)} 字节 (优化实时性)")
        return bytes(pcm_bytes)
    
    def start_streaming(self):
        """启动AWS Transcribe流式转录"""
        try:
            logger.info("🚀 启动AWS Transcribe Streaming...")
            VoiceHandler.streaming_active = True
            VoiceHandler.audio_queue = queue.Queue()
            VoiceHandler.latest_transcript = ""
            
            # 创建音频文件保存PCM数据 - 已禁用
            # VoiceHandler.audio_counter += 1
            # audio_filename = f"received_audio_{VoiceHandler.audio_counter}.pcm"
            # VoiceHandler.audio_file = open(audio_filename, 'wb')
            # logger.info(f"📁 创建音频文件: {audio_filename}")
            
            # 在新线程中运行转录
            threading.Thread(target=self.run_transcription, daemon=True).start()
            
        except Exception as e:
            logger.error(f"❌ 启动流式转录失败: {e}")
            VoiceHandler.streaming_active = False
    
    def stop_streaming(self):
        """停止流式转录"""
        VoiceHandler.streaming_active = False
        if VoiceHandler.audio_queue:
            VoiceHandler.audio_queue.put(None)  # 停止信号
        
        # 关闭音频文件 - 已禁用
        # if VoiceHandler.audio_file:
        #     VoiceHandler.audio_file.close()
        #     VoiceHandler.audio_file = None
        #     logger.info("📁 音频文件已保存并关闭")
        
        logger.info("🛑 停止AWS Transcribe Streaming")
    
    def run_transcription(self):
        """运行AWS Transcribe流式转录"""
        try:
            logger.info("🔄 初始化Transcribe客户端...")
            
            def transcript_callback(text, is_final=False):
                logger.info(f"📞 回调函数被调用: '{text}' (最终: {is_final})")
                # 存储转录结果和类型
                VoiceHandler.latest_transcript = text
                VoiceHandler.is_final_result = is_final
                logger.info(f"📝 更新转录: {text} ({'最终' if is_final else '部分'})")
                
                # 实时翻译：只启动翻译，不修改翻译状态
                if text.strip():
                    logger.info(f"🚀 启动实时翻译: '{text}' ({'最终' if is_final else '部分'})")
                    # 不修改 latest_translation，保持已有的翻译结果
                    executor.submit(VoiceHandler.async_translate_instance, text, is_final)
            
            # 创建异步事件循环
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            async def stream_transcription():
                client = TranscribeStreamingClient(region="us-east-1")
                
                logger.info("🔧 启动转录流参数: 自动语言检测=True, sample_rate=16000, encoding=pcm")
                stream = await client.start_stream_transcription(
                    language_code=None,  # 使用自动语言检测时设为None
                    identify_language=True,  # 启用自动语言检测
                    language_options=["en-US", "zh-CN", "ja-JP", "hi-IN", "id-ID", "tl-PH", "ru-RU"],  # 每种语言只保留一个地区版本
                   #language_options=["en-US", "zh-CN", "ja-JP","en-IN", "hi-IN","id-ID", "tl-PH", "ru-RU"],  # 支持的语言印度印地语,印度尼西亚语,印度英语，Tagalog/Filipino  他加禄语/菲律宾语，Hindi, Indian  印度印地语
                    preferred_language="en-US",  # 首选语言
                    media_sample_rate_hz=16000,
                    media_encoding="pcm"
                )
                
                # 创建事件处理器
                handler = MyEventHandler(stream.output_stream, transcript_callback)
                
                logger.info("✅ 转录流已启动")
                
                # 启动事件处理任务
                async def handle_events():
                    logger.info("🎧 开始监听转录事件...")
                    try:
                        async for event in stream.output_stream:
                            logger.info(f"📨 收到转录事件: {type(event).__name__}")
                            await handler.handle_transcript_event(event)
                    except Exception as e:
                        logger.error(f"❌ 事件处理错误: {e}")
                
                # 同时运行音频发送和事件处理
                import asyncio
                event_task = asyncio.create_task(handle_events())
                
                # 发送音频数据
                try:
                    while VoiceHandler.streaming_active:
                        try:
                            audio_chunk = VoiceHandler.audio_queue.get(timeout=1.0)
                            if audio_chunk is None:  # 停止信号
                                logger.info("🛑 收到停止信号")
                                break
                            
                            logger.info(f"📤 准备发送音频块: {len(audio_chunk)} 字节")
                            await stream.input_stream.send_audio_event(audio_chunk=audio_chunk)
                            logger.info(f"✅ 音频块发送成功: {len(audio_chunk)} 字节")
                            
                        except queue.Empty:
                            logger.debug("⏰ 队列超时，继续等待...")
                            continue
                        except Exception as e:
                            logger.error(f"❌ 发送音频错误: {e}")
                            break
                    
                    # 结束流
                    await stream.input_stream.end_stream()
                    logger.info("🔚 音频流已结束")
                    
                    # 等待事件处理完成
                    await event_task
                        
                except Exception as e:
                    logger.error(f"❌ 流处理错误: {e}")
                    event_task.cancel()
            
            # 运行转录
            loop.run_until_complete(stream_transcription())
            
        except Exception as e:
            logger.error(f"💥 转录线程错误: {e}")
        finally:
            VoiceHandler.streaming_active = False
            logger.info("🏁 转录线程结束")
    
    @staticmethod
    def async_translate_instance(text, is_final=True):
        """静态异步翻译函数 - 参考转录逻辑实现追加"""
        try:
            logger.info(f"🌐 开始翻译: '{text}' ({'最终' if is_final else '部分'})")
            
            # 执行翻译
            translation = VoiceHandler.translate_text_static(text)
            
            if is_final:
                # 最终结果：追加到历史记录（参考转录逻辑）
                VoiceHandler.final_translation_history += (VoiceHandler.final_translation_history and ' ' or '') + translation
                VoiceHandler.latest_translation = VoiceHandler.final_translation_history
                VoiceHandler.translation_is_final = True
                VoiceHandler.translation_cache[text] = translation
                logger.info(f"✅ 最终翻译追加: '{translation}' -> 历史: '{VoiceHandler.final_translation_history}'")
            else:
                # 部分结果：显示历史记录 + 当前部分结果（参考转录逻辑）
                display_translation = VoiceHandler.final_translation_history + (VoiceHandler.final_translation_history and ' ' or '') + translation
                VoiceHandler.latest_translation = display_translation
                VoiceHandler.translation_is_final = False
                logger.info(f"🔄 部分翻译显示: '{translation}' -> 显示: '{display_translation}'")
                
        except Exception as e:
            logger.error(f"❌ 翻译失败: {e}")
            VoiceHandler.latest_translation = "Translation failed"
            VoiceHandler.translation_is_final = is_final
    
    @staticmethod
    def translate_text_static(text):
        """静态翻译函数"""
        try:
            if not text or text in ["🎧 正在监听...", "🔇 音频数据太短"]:
                return "Listening..." if "监听" in text else "Audio data too short"
            
            # 根据设置的目标语言生成提示词
            if VoiceHandler.translation_language == 'en':
                prompt = f"请将以下文本翻译成英文，只返回翻译结果：{text}"
            elif VoiceHandler.translation_language == 'zh':
                prompt = f"请将以下文本翻译成中文，只返回翻译结果：{text}"
            else:  # ja
                prompt = f"请将以下文本翻译成日语，只返回翻译结果：{text}"
            
            # 根据选择的模型设置不同的模型ID
            if VoiceHandler.translation_model == 'nova':
                model_id = 'us.amazon.nova-lite-v1:0'
                body = {
                    "messages": [{"role": "user", "content": [{"text": prompt}]}],
                    "inferenceConfig": {
                        "maxTokens": 1000,
                        "temperature": 0.3
                    }
                }
            else:  # claude
                model_id = 'us.anthropic.claude-3-5-haiku-20241022-v1:0'
                body = {
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": 1000,
                    "messages": [{"role": "user", "content": prompt}]
                }
            
            response = bedrock.invoke_model(
                modelId=model_id,
                body=json.dumps(body)
            )
            
            result = json.loads(response['body'].read())
            
            # 根据不同模型解析响应
            if VoiceHandler.translation_model == 'nova':
                translation = result['output']['message']['content'][0]['text'].strip()
            else:  # claude
                translation = result['content'][0]['text'].strip()
            
            lang_name = {'en': '英文', 'zh': '中文', 'ja': '日语'}[VoiceHandler.translation_language]
            model_name = {'claude': 'Claude 3.5 Haiku', 'nova': 'Amazon Nova Lite'}[VoiceHandler.translation_model]
            logger.info(f"🌐 翻译(模型: {model_name}, 目标语言: {lang_name}): {text} -> {translation}")
            return translation
            
        except Exception as e:
            logger.error(f"❌ 翻译失败: {e}")
            return f"Translation failed: {str(e)}"
    
    def translate_and_cache(self, text, is_final=True):
        """翻译并缓存 - 支持实时翻译"""
        try:
            logger.info(f"🌐 [翻译开始] 文本: '{text}' ({'最终' if is_final else '部分'})")
            
            # 执行翻译
            translation = self.translate_text(text)
            logger.info(f"🎯 [翻译结果] '{text}' -> '{translation}'")
            
            # 立即更新翻译状态
            VoiceHandler.latest_translation = translation
            VoiceHandler.translation_is_final = is_final
            
            # 只缓存最终结果，避免部分结果污染缓存
            if is_final:
                VoiceHandler.translation_cache[text] = translation
                logger.info(f"✅ [最终翻译] 已缓存: '{text}' -> '{translation}'")
            else:
                logger.info(f"🔄 [部分翻译] 完成: '{text}' -> '{translation}'")
            
        except Exception as e:
            logger.error(f"❌ [翻译失败] 错误: {e}")
            error_msg = "Translation failed"
            VoiceHandler.latest_translation = error_msg
            VoiceHandler.translation_is_final = is_final
            if is_final:
                VoiceHandler.translation_cache[text] = error_msg
    
    def async_translate(self, text):
        """保留原方法以兼容"""
        self.translate_and_cache(text)
    def translate_text(self, text):
        """同步翻译函数"""
        try:
            if not text or text in ["🎧 正在监听...", "🔇 音频数据太短"]:
                return "Listening..." if "监听" in text else "Audio data too short"
            
            # 根据设置的目标语言生成提示词
            if VoiceHandler.translation_language == 'en':
                prompt = f"请将以下文本翻译成英文，只返回翻译结果：{text}"
            elif VoiceHandler.translation_language == 'zh':
                prompt = f"请将以下文本翻译成中文，只返回翻译结果：{text}"
            else:  # ja
                prompt = f"请将以下文本翻译成日语，只返回翻译结果：{text}"
            
            # 根据选择的模型设置不同的模型ID
            if VoiceHandler.translation_model == 'nova':
                model_id = 'us.amazon.nova-lite-v1:0'
                body = {
                    "messages": [{"role": "user", "content": [{"text": prompt}]}],
                    "inferenceConfig": {
                        "maxTokens": 1000,
                        "temperature": 0.3
                    }
                }
            else:  # claude
                model_id = 'us.anthropic.claude-3-5-haiku-20241022-v1:0'
                body = {
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": 1000,
                    "messages": [{"role": "user", "content": prompt}]
                }
            
            response = bedrock.invoke_model(
                modelId=model_id,
                body=json.dumps(body)
            )
            
            result = json.loads(response['body'].read())
            
            # 根据不同模型解析响应
            if VoiceHandler.translation_model == 'nova':
                translation = result['output']['message']['content'][0]['text'].strip()
            else:  # claude
                translation = result['content'][0]['text'].strip()
            
            lang_name = {'en': '英文', 'zh': '中文', 'ja': '日语'}[VoiceHandler.translation_language]
            model_name = {'claude': 'Claude 3.5 Haiku', 'nova': 'Amazon Nova Lite'}[VoiceHandler.translation_model]
            logger.info(f"🌐 翻译(模型: {model_name}, 目标语言: {lang_name}): {text} -> {translation}")
            return translation
            
        except Exception as e:
            logger.error(f"❌ 翻译失败: {e}")
            return f"Translation failed: {str(e)}"

if __name__ == '__main__':
    # 检查AWS凭证
    try:
        sts = boto3.client('sts')
        identity = sts.get_caller_identity()
        logger.info(f"AWS Identity: {identity.get('Arn', 'Unknown')}")
    except Exception as e:
        logger.error(f"AWS credentials error: {e}")
    
    server = HTTPServer(('0.0.0.0', 3001), VoiceHandler)
    logger.info("🎤 启动AWS Transcribe Streaming服务器: http://0.0.0.0:3001")
    logger.info("📡 使用真实的AWS Transcribe Streaming API")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Server stopped")
        VoiceHandler.stop_streaming()
        server.shutdown()
