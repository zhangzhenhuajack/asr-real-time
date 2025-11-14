# AWS实时语音转录翻译应用

基于AWS服务的实时语音转录和翻译应用，支持多语言识别和AI翻译。

![info.png](info.png)
[英语-n.mov](%E8%8B%B1%E8%AF%AD-n.mov)

## 🏗️ 架构

- **前端**: React.js + S3 + CloudFront
- **后端**: ECS Fargate + ALB  + Global Accelerator
- **AI服务**: AWS Transcribe + Amazon Bedrock (Claude 3.5 Haiku / Nova Lite)

## 低延迟的建议部署方案
1. 后端建议和TranscribeStreamingClient 调用的region在同一个地方
2. 后端建议通过AGA进行加速

## 📁 项目结构

```
live-asr-q/
├── README.md                       # 项目说明
├── backend/
│   ├── streaming_transcribe_server.py  # HTTP服务器
│   └── requirements.txt                 # Python依赖
└── frontend/
    ├── package.json               # 前端依赖
    └── src/
        ├── App.js                 # React应用
        ├── App.css                # 样式文件
        └── index.js               # 入口文件
```

## 🚀 快速部署

### 前置要求

1. **AWS CLI** - 已配置凭证和默认区域
2. **Docker** - 用于构建容器镜像
3. **Node.js & npm** - 用于构建前端
4. **AWS权限** - 需要ECS、ECR、S3、CloudFront、Global Accelerator等权限


## 🎯 功能特性

- ✅ **实时语音转录** - 基于AWS Transcribe Streaming
- ✅ **多语言识别** - 支持中文、英文、日语等
- ✅ **AI智能翻译** - Claude 3.5 Haiku / Amazon Nova Lite
- ✅ **实时流式处理** - 低延迟音频处理
- ✅ **HTTPS安全连接** - CloudFront SSL终端
- ✅ **全球加速** - Global Accelerator优化网络性能
- ✅ **自动扩缩容** - ECS Fargate无服务器架构

## 🌐 支持的语言

### 语音识别语言
应用支持自动语言检测，可识别以下语言：
- 🇺🇸 **英语** (美国) - en-US
- 🇨🇳 **中文** (普通话) - zh-CN  
- 🇯🇵 **日语** - ja-JP
- 🇮🇳 **印地语** - hi-IN
- 🇮🇩 **印尼语** - id-ID
- 🇵🇭 **他加禄语/菲律宾语** - tl-PH
- 🇷🇺 **俄语** - ru-RU

### 翻译目标语言
AI翻译支持以下目标语言：
- 🇺🇸 **英文** (en) - 翻译为英语
- 🇨🇳 **中文** (zh) - 翻译为中文
- 🇯🇵 **日语** (ja) - 翻译为日语

### AI翻译模型
- 🤖 **Claude 3.5 Haiku** - 高质量翻译，响应快速
- 🚀 **Amazon Nova Lite** - 轻量级模型，成本更低

## 🔧 使用方法

1. 访问部署完成后提供的前端URL
2. 点击"开始录音"按钮
3. 对着麦克风说话
4. 实时查看转录和翻译结果
5. 可切换翻译语言和AI模型

## 🛠️ 故障排除

### 常见问题

1. **部署失败** - 检查AWS凭证和权限
2. **容器启动失败** - 查看ECS任务日志
3. **前端无法访问** - 检查S3存储桶策略和CloudFront配置
4. **转录不工作** - 确认麦克风权限和网络连接

## 📝 许可证

MIT License

## 🔮 TODO

1. ✅ 统一基础设施模板
2. ⏳ 改造成WebSocket版本可能更快
3. ⏳ 添加监控告警
4. ⏳ 多环境支持
5. ⏳ 自定义域名和SSL证书