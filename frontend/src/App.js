import React, { useState, useRef, useEffect } from 'react';
import Login from './Login';
import config from './config';
import './App.css';

function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [translation, setTranslation] = useState('');
  const [status, setStatus] = useState('未连接');
  const [isStreaming, setIsStreaming] = useState(false);
  const [audioLevel, setAudioLevel] = useState(0);
  const [processingTime, setProcessingTime] = useState(0);
  const [chunkCount, setChunkCount] = useState(0);
  const [debugLogs, setDebugLogs] = useState([]);
  const [translationLanguage, setTranslationLanguage] = useState('zh'); // 翻译语言
  const [selectedModel, setSelectedModel] = useState('claude'); // 选择的模型
  
  const mediaRecorderRef = useRef(null);
  const streamRef = useRef(null);
  const intervalRef = useRef(null);
  const finalTranscriptRef = useRef('');
  const finalTranslationRef = useRef('');

  const addDebugLog = (message) => {
    const timestamp = new Date().toLocaleTimeString();
    setDebugLogs(prev => [...prev.slice(-9), `[${timestamp}] ${message}`]);
  };

  useEffect(() => {
    setStatus('就绪 (AWS Transcribe Streaming)');
    addDebugLog('应用初始化完成');
  }, []);

  const startRecording = async () => {
    try {
      addDebugLog('🎤 开始请求麦克风权限...');
      console.log('🎤 开始请求麦克风权限...');
      
      streamRef.current = await navigator.mediaDevices.getUserMedia({ 
        audio: { 
          sampleRate: 16000, 
          channelCount: 1,
          echoCancellation: true,
          noiseSuppression: true
        } 
      });
      
      addDebugLog('✅ 麦克风权限获取成功');
      console.log('✅ 麦克风权限获取成功');
      
      // 使用Web Audio API获取PCM数据
      const audioContext = new (window.AudioContext || window.webkitAudioContext)({
        sampleRate: 16000
      });
      
      const source = audioContext.createMediaStreamSource(streamRef.current);
      const processor = audioContext.createScriptProcessor(1024, 1, 1); // 进一步减少缓冲区
      
      addDebugLog(`🎵 AudioContext创建: sampleRate=${audioContext.sampleRate}`);
      console.log('🎵 AudioContext 创建成功, sampleRate:', audioContext.sampleRate);
      
      // 启动流式转录
      setIsStreaming(true);
      setChunkCount(0);
      
      processor.onaudioprocess = async (event) => {
        const inputBuffer = event.inputBuffer;
        const inputData = inputBuffer.getChannelData(0); // 获取单声道PCM数据
        
        // 增加音频增益
        const gainFactor = 10; // 增加10倍增益
        const amplifiedData = new Float32Array(inputData.length);
        for (let i = 0; i < inputData.length; i++) {
          amplifiedData[i] = Math.max(-1, Math.min(1, inputData[i] * gainFactor));
        }
        
        // 转换为数组发送
        const pcmArray = Array.from(amplifiedData);
        
        const logMsg = `🔊 PCM数据: ${pcmArray.length}样本`;
        addDebugLog(logMsg);
        console.log('🔊 PCM数据可用 - 样本数:', pcmArray.length);
        console.log('🔢 前10个样本:', pcmArray.slice(0, 10));
        
        // 计算音频级别
        const rms = Math.sqrt(pcmArray.reduce((sum, sample) => sum + sample * sample, 0) / pcmArray.length);
        console.log('🎵 音频RMS:', rms);
        
        if (pcmArray.length > 0 && rms > 0.001) { // 进一步降低阈值
          console.log('📤 准备发送PCM数据...');
          await sendPCMChunk(pcmArray);
        } else {
          console.log('⚠️ 音频信号太弱，跳过发送');
        }
      };

      source.connect(processor);
      processor.connect(audioContext.destination);
      
      // 保存引用以便清理
      streamRef.audioContext = audioContext;
      streamRef.processor = processor;
      
      setIsRecording(true);
      setStatus('录音中... (实时转录)');
      
      addDebugLog('✅ Web Audio API录音启动完成');
      console.log('✅ Web Audio API录音启动完成');
      
    } catch (error) {
      const errorMsg = `❌ 录音失败: ${error.message}`;
      addDebugLog(errorMsg);
      console.error('❌ 录音启动失败:', error);
      setStatus(`录音失败: ${error.message}`);
    }
  };

  const stopRecording = () => {
    // 清理Web Audio API资源
    if (streamRef.processor) {
      streamRef.processor.disconnect();
    }
    if (streamRef.audioContext) {
      streamRef.audioContext.close();
    }
    if (streamRef.current) {
      streamRef.current.getTracks().forEach(track => track.stop());
    }
    
    setIsRecording(false);
    setIsStreaming(false);
    setStatus('录音已停止');
    
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
    }
    
    // 通知后端停止流式转录
    fetch(`${config.api.baseUrl}/disconnect`, {
      method: 'GET'
    }).catch(console.error);
  };

  const resetAll = () => {
    setTranscript('');
    setTranslation('');
    setAudioLevel(0);
    setProcessingTime(0);
    setChunkCount(0);
    setStatus('已重置');
    finalTranscriptRef.current = '';
    finalTranslationRef.current = '';
    addDebugLog('🔄 界面已重置');
  };

  const sendPCMChunk = async (pcmArray) => {
    const startTime = Date.now();
    const chunkId = Date.now();
    
    try {
      console.log(`📦 [Chunk ${chunkId}] 开始处理PCM数据`);
      console.log(`📏 [Chunk ${chunkId}] PCM样本数: ${pcmArray.length}`);
      console.log(`🔢 [Chunk ${chunkId}] 前10个样本:`, pcmArray.slice(0, 10));
      
      // 计算音频级别
      const rms = Math.sqrt(pcmArray.reduce((sum, sample) => sum + sample * sample, 0) / pcmArray.length);
      const level = Math.min(100, Math.max(0, rms * 1000));
      setAudioLevel(level);
      
      const response = await fetch(`${config.api.baseUrl}/audio`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          data: pcmArray,
          timestamp: new Date().toISOString(),
          chunkId: chunkId
        })
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const result = await response.json();
      console.log(`📨 [Chunk ${chunkId}] 服务器响应:`, result);
      console.log(`🔍 [Chunk ${chunkId}] 转录内容: "${result.transcript}", 是否最终: ${result.is_final}`);
      
      if (result.transcript && result.transcript !== '🎧 正在监听...') {
        const newText = result.transcript.trim();
        const isFinal = result.is_final === true; // 明确检查布尔值
        
        console.log(`📝 [Chunk ${chunkId}] 处理转录: "${newText}", 最终: ${isFinal}, 原始is_final: ${result.is_final}`);
        console.log(`📚 [Chunk ${chunkId}] 当前历史: "${finalTranscriptRef.current}"`);
        
        if (isFinal) {
          // 最终结果：追加到历史记录
          finalTranscriptRef.current += (finalTranscriptRef.current ? ' ' : '') + newText;
          setTranscript(finalTranscriptRef.current);
          addDebugLog(`📝 最终转录: ${newText}`);
          console.log(`✅ [Chunk ${chunkId}] 最终结果已保存: "${finalTranscriptRef.current}"`);
        } else {
          // 部分结果：显示历史记录 + 当前部分结果
          const displayText = finalTranscriptRef.current + (finalTranscriptRef.current ? ' ' : '') + newText;
          setTranscript(displayText);
          console.log(`🔄 [Chunk ${chunkId}] 部分结果显示: "${displayText}"`);
        }
      } else {
        console.log(`⚠️ [Chunk ${chunkId}] 跳过转录: "${result.transcript}"`);
      }
      
      if (result.translation && 
          result.translation !== 'Listening...' && 
          result.translation !== 'Processing...' && 
          result.translation !== 'Translating...') {
        const newTranslation = result.translation.trim();
        const translationIsFinal = result.translation_is_final === true; // 使用翻译专用的状态
        
        console.log(`🌐 [Chunk ${chunkId}] 翻译处理: "${newTranslation}", 最终: ${translationIsFinal}`);
        
        if (translationIsFinal) {
          // 最终结果：追加到历史记录
          finalTranslationRef.current += (finalTranslationRef.current ? ' ' : '') + newTranslation;
          setTranslation(finalTranslationRef.current);
          addDebugLog(`🌐 最终翻译: ${newTranslation}`);
          console.log(`✅ [Chunk ${chunkId}] 最终翻译已保存: "${finalTranslationRef.current}"`);
        } else {
          // 部分结果：显示历史记录 + 当前部分结果
          const displayTranslation = finalTranslationRef.current + (finalTranslationRef.current ? ' ' : '') + newTranslation;
          setTranslation(displayTranslation);
          console.log(`🔄 [Chunk ${chunkId}] 部分翻译显示: "${displayTranslation}"`);
        }
      } else if (result.translation === 'Listening...' && !finalTranslationRef.current) {
        // 只在没有历史翻译时才显示 Listening...
        setTranslation('等待翻译...');
      }
      
      const processingTimeMs = Date.now() - startTime;
      setProcessingTime(processingTimeMs);
      setChunkCount(prev => prev + 1);
      
      console.log(`⏱️ [Chunk ${chunkId}] 处理时间: ${processingTimeMs}ms`);
      
    } catch (error) {
      console.error(`❌ [Chunk ${chunkId}] 发送失败:`, error);
      addDebugLog(`❌ 发送失败: ${error.message}`);
    }
  };

  const sendAudioChunk = async (audioBlob) => {
    const startTime = Date.now();
    const chunkId = Date.now();
    
    try {
      console.log(`📦 [Chunk ${chunkId}] 开始处理音频块`);
      console.log(`📏 [Chunk ${chunkId}] Blob大小: ${audioBlob.size} 字节`);
      console.log(`🎵 [Chunk ${chunkId}] Blob类型: ${audioBlob.type}`);
      
      const arrayBuffer = await audioBlob.arrayBuffer();
      console.log(`🔄 [Chunk ${chunkId}] ArrayBuffer大小: ${arrayBuffer.byteLength} 字节`);
      
      const audioArray = Array.from(new Uint8Array(arrayBuffer));
      console.log(`📊 [Chunk ${chunkId}] 转换后数组长度: ${audioArray.length}`);
      console.log(`🔢 [Chunk ${chunkId}] 前10个字节:`, audioArray.slice(0, 10));
      
      // 计算音频级别
      const level = Math.min(100, Math.max(0, (audioArray.length / 1000) * 10));
      setAudioLevel(level);
      setChunkCount(prev => {
        const newCount = prev + 1;
        console.log(`📈 [Chunk ${chunkId}] 音频块计数: ${newCount}`);
        return newCount;
      });
      
      const requestData = {
        action: 'audio',
        data: audioArray,
        timestamp: chunkId,
        metadata: {
          originalSize: audioBlob.size,
          arrayLength: audioArray.length,
          chunkId: chunkId
        }
      };
      
      console.log(`📤 [Chunk ${chunkId}] 发送请求到后端...`);
      
      const response = await fetch(`${config.api.baseUrl}/audio`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestData)
      });
      
      const processingDuration = Date.now() - startTime;
      setProcessingTime(processingDuration);
      
      console.log(`📥 [Chunk ${chunkId}] 响应状态: ${response.status}`);
      console.log(`⏱️ [Chunk ${chunkId}] 处理时间: ${processingDuration}ms`);
      
      if (response.ok) {
        const data = await response.json();
        console.log(`✅ [Chunk ${chunkId}] 响应数据:`, data);
        
        // 更新状态
        if (data.status === 'processing') {
          console.log(`🔄 [Chunk ${chunkId}] 状态: 处理中`);
          setStatus('处理中...');
        } else if (data.transcript && data.transcript !== '正在处理音频...') {
          console.log(`📝 [Chunk ${chunkId}] 设置转录文本:`, data.transcript);
          setTranscript(data.transcript);
          
          if (data.translation) {
            console.log(`🌐 [Chunk ${chunkId}] 设置翻译文本:`, data.translation);
            setTranslation(data.translation);
          }
          setStatus('转录成功');
        } else {
          console.log(`⏳ [Chunk ${chunkId}] 等待转录结果...`);
        }
      } else {
        console.error(`❌ [Chunk ${chunkId}] HTTP错误: ${response.status}`);
        const errorText = await response.text();
        console.error(`❌ [Chunk ${chunkId}] 错误详情:`, errorText);
        setStatus(`处理失败: ${response.status}`);
      }
    } catch (error) {
      console.error(`💥 [Chunk ${chunkId}] 发送失败:`, error);
      console.error(`💥 [Chunk ${chunkId}] 错误堆栈:`, error.stack);
      setStatus(`网络错误: ${error.message}`);
    }
  };

  const checkTranscriptionResults = async () => {
    // 这里可以添加轮询逻辑来获取最新的转录结果
    // 在实际应用中，建议使用WebSocket来实时接收结果
  };

  const testConnection = async () => {
    try {
      const response = await fetch(`${config.api.baseUrl}/connect`);
      if (response.ok) {
        const data = await response.json();
        setStatus(`连接成功: ${data.message}`);
      } else {
        setStatus('连接失败');
      }
    } catch (error) {
      setStatus('连接错误');
    }
  };

  const handleLanguageChange = async (event) => {
    const newLanguage = event.target.value;
    try {
      const response = await fetch(`${config.api.baseUrl}/set_language`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ language: newLanguage })
      });
      
      if (response.ok) {
        const result = await response.json();
        setTranslationLanguage(newLanguage);
        addDebugLog(`🌐 翻译目标语言: ${newLanguage === 'en' ? '英文' : newLanguage === 'zh' ? '中文' : '日语'}`);
        
        // 清空翻译结果
        setTranslation('');
        finalTranslationRef.current = '';
      }
    } catch (error) {
      console.error('切换语言失败:', error);
      addDebugLog(`❌ 切换语言失败: ${error.message}`);
    }
  };

  const handleModelChange = async (event) => {
    const newModel = event.target.value;
    try {
      const response = await fetch(`${config.api.baseUrl}/set_model`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ model: newModel })
      });
      
      if (response.ok) {
        const result = await response.json();
        setSelectedModel(newModel);
        const modelName = newModel === 'claude' ? 'Claude 3.5 Haiku' : 'Amazon Nova Lite';
        addDebugLog(`🤖 翻译模型: ${modelName}`);
        
        // 清空翻译结果
        setTranslation('');
        finalTranslationRef.current = '';
      }
    } catch (error) {
      console.error('切换模型失败:', error);
      addDebugLog(`❌ 切换模型失败: ${error.message}`);
    }
  };

  const testAudio = async () => {
    try {
      setStatus('测试音频处理...');
      
      // 发送测试音频数据
      const testData = Array.from({length: 2000}, (_, i) => i % 256);
      
      const response = await fetch(`${config.api.baseUrl}/audio`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          action: 'audio',
          data: testData,
          timestamp: Date.now()
        })
      });
      
      if (response.ok) {
        const data = await response.json();
        console.log('Test response:', data);
        
        setTranscript(data.transcript);
        setTranslation(data.translation);
        setStatus('测试成功');
      } else {
        setStatus('测试失败');
      }
    } catch (error) {
      console.error('测试失败:', error);
      setStatus('测试错误');
    }
  };

  const handleLogin = (loginStatus) => {
    setIsLoggedIn(loginStatus);
  };

  const handleLogout = () => {
    setIsLoggedIn(false);
    // 重置所有状态
    setIsRecording(false);
    setTranscript('');
    setTranslation('');
    setStatus('未连接');
    setAudioLevel(0);
    setProcessingTime(0);
    setChunkCount(0);
    setDebugLogs([]);
    finalTranscriptRef.current = '';
    finalTranslationRef.current = '';
  };

  // 如果未登录，显示登录页面
  if (!isLoggedIn) {
    return <Login onLogin={handleLogin} />;
  }

  return (
    <div className="App">
      <div className="app-container">
        {/* 顶部控制区 */}
        <div className="top-section">
          <div className="header">
            <div className="header-content">
              <h1>🎤 AWS实时语音转录翻译</h1>
              <button className="logout-btn" onClick={handleLogout}>
                退出登录
              </button>
            </div>
            <div className="status-bar">
              <span className="status-text">状态: {status}</span>
              {isStreaming && <div className="live-indicator">🔴 LIVE</div>}
            </div>
          </div>
          
          <div className="controls-section">
            <div className="main-controls">
              <button 
                className={`record-btn ${isRecording ? 'recording' : ''}`}
                onClick={isRecording ? stopRecording : startRecording}
              >
                {isRecording ? '⏹️ 停止录音' : '🎤 开始录音'}
              </button>
              
              <div className="language-control">
                <label>翻译语言:</label>
                <select 
                  value={translationLanguage} 
                  onChange={handleLanguageChange}
                  className="language-select"
                >
                  <option value="en">🇺🇸 英文</option>
                  <option value="zh">🇨🇳 中文</option>
                  <option value="ja">🇯🇵 日语</option>
                </select>
              </div>
              
              <div className="model-control">
                <label>翻译模型:</label>
                <select 
                  value={selectedModel} 
                  onChange={handleModelChange}
                  className="model-select"
                >
                  <option value="claude">🧠 Claude 3.5 Haiku</option>
                  <option value="nova">⭐ Amazon Nova Lite</option>
                </select>
              </div>
              
              <button className="reset-btn" onClick={resetAll}>
                🔄 重置
              </button>
              
              <button className="test-btn" onClick={testConnection}>
                🔗 测试连接
              </button>
              <button className="test-btn" onClick={testAudio}>
                🎵 测试音频
              </button>
            </div>
          </div>

          {isRecording && (
            <div className="monitor-panel">
              <div className="monitor-item">
                <span className="monitor-label">音频级别</span>
                <div className="audio-level-bar">
                  <div className="audio-level-fill" style={{width: `${audioLevel}%`}}></div>
                </div>
                <span className="monitor-value">{audioLevel.toFixed(0)}%</span>
              </div>
              
              <div className="monitor-item">
                <span className="monitor-label">处理延迟</span>
                <span className="monitor-value">{processingTime}ms</span>
              </div>
              
              <div className="monitor-item">
                <span className="monitor-label">音频块数</span>
                <span className="monitor-value">{chunkCount}</span>
              </div>
            </div>
          )}
        </div>

        {/* 中间结果显示区 */}
        <div className="middle-section">
          <div className="results-container">
            <div className="result-panel transcript-panel">
              <div className="panel-header">
                <h3>🎤 转录文本</h3>
                <div className="panel-status">
                  {isStreaming && <span className="streaming-badge">实时转录中</span>}
                </div>
              </div>
              <div className="result-content">
                <p>{transcript || '等待语音输入...'}</p>
              </div>
            </div>
            
            <div className="result-panel translation-panel">
              <div className="panel-header">
                <h3>🌐 翻译结果</h3>
                <div className="panel-status">
                  <span className="language-badge">
                    {translationLanguage === 'en' ? '🇺🇸 EN' : 
                     translationLanguage === 'zh' ? '🇨🇳 ZH' : '🇯🇵 JA'}
                  </span>
                </div>
              </div>
              <div className="result-content">
                <p>{translation || '等待翻译...'}</p>
              </div>
            </div>
          </div>
        </div>

        {/* 底部信息区 */}
        <div className="bottom-section">
          <div className="debug-panel">
            <h4>🔍 调试日志</h4>
            <div className="log-container">
              {debugLogs.map((log, index) => (
                <div key={index} className="log-entry">{log}</div>
              ))}
              {debugLogs.length === 0 && (
                <div className="log-entry">等待日志...</div>
              )}
            </div>
          </div>
          
          <div className="tech-panel">
            <h4>⚡ 技术架构</h4>
            <div className="tech-items">
              <div className="tech-item">
                <span className="tech-icon">🎵</span>
                <span className="tech-text">16kHz PCM音频</span>
              </div>
              <div className="tech-item">
                <span className="tech-icon">🤖</span>
                <span className="tech-text">AWS Transcribe</span>
              </div>
              <div className="tech-item">
                <span className="tech-icon">🧠</span>
                <span className="tech-text">
                  {selectedModel === 'claude' ? 'Claude 3.5 Haiku' : 'Amazon Nova Lite'}
                </span>
              </div>
              <div className="tech-item">
                <span className="tech-icon">⚡</span>
                <span className="tech-text">实时流式处理</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
