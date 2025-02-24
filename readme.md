# AI-Translator

一個基於 AutoHotkey v2 開發的多功能 AI 翻譯工具，支持多個 AI 模型進行即時翻譯和文本處理。

## 功能特點

- 🚀 快速啟動：使用 CapsLock 鍵快速調用翻譯功能
- 🔄 多模型支援：
  - Claude API
  - OpenAI API
  - Akash API
- 💡 多種翻譯模式：
  - 翻譯成英文
  - 翻譯成繁體中文
  - 英文文法修正
- 🎨 現代化界面：
  - 簡潔的操作界面
  - 支援視窗大小調整
  - Tiffany Blue 主題設計
- 🔧 便捷功能：
  - 系統托盤圖標
  - 快速複製結果
  - 支援快速切換翻譯服務商

## 系統需求

- Windows 作業系統
- AutoHotkey v2.0 或更高版本
- curl 命令行工具（用於 API 請求）

## 安裝步驟

1. 安裝 [AutoHotkey v2](https://www.autohotkey.com/)
2. 下載本專案檔案
3. 在專案根目錄建立 `api.ini` 設定檔，填入 API 金鑰：
```ini
[Claude]
ApiKey=sk-ant-api03-你的Claude金鑰
Model=claude-3-haiku-20240307
Endpoint=https://api.anthropic.com/v1/messages
Version=2023-06-01

[OpenAI]
ApiKey=sk-你的OpenAI金鑰
Model=gpt-4
Endpoint=https://api.openai.com/v1/chat/completions
Version=

[Akash]
ApiKey=sk-你的Akash金鑰
Model=Meta-Llama-3-1-8B-Instruct-FP8
Endpoint=https://chatapi.akash.network/api/v1/chat/completions
Version=
```

## 使用方法

1. 運行 `ai-translator.ahk`
2. 選取要翻譯的文字
3. 按下 CapsLock 鍵
4. 在彈出的選單中選擇所需的翻譯模式
5. 等待翻譯完成

## 快捷鍵

- `CapsLock`: 顯示翻譯選單
- `Shift + CapsLock`: 切換 CapsLock 狀態

## 自訂設定

- 可在系統托盤圖標選單中切換不同的 AI 服務商
- 預設使用 Akash API 作為翻譯服務
- 可通過修改 `api.ini` 更新 API 設定

## 注意事項

- 請確保 `api.ini` 檔案中填入了正確的 API 金鑰
- 翻譯時需要保持網路連接
- 建議定期備份 `api.ini` 檔案

## 貢獻指南

歡迎提交 Issue 和 Pull Request 來幫助改進這個專案。

## 授權協議

[MIT License](LICENSE)
