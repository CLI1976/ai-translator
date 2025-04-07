#Requires AutoHotkey v2.0
#SingleInstance Force
#Include jsongo.v2.ahk

CoordMode("Mouse", "Screen")  ; 設置滑鼠為螢幕坐標模式
CoordMode("Menu", "Screen")   ; 設置選單為螢幕坐標模式

; 全局變數
global CurrentProvider := "Akash"  ; 預設使用 Akash
; 保存剪貼簿內容的全局變數
global SavedClipboard := ""
global SelectedText := ""  ; 新增變數保存選取的文字


; 創建進度提示 GUI 類
class ProgressTip {
    static hwnd := 0
    
    static Show(text := "正在處理中...") {
        try {
            ; 如果已存在則先關閉
            if (this.hwnd != 0) {
                this.Hide()
            }
            
            ; 創建半透明提示視窗
            progressGui := Gui("+AlwaysOnTop +ToolWindow -Caption")  ; 移除 -Caption 先測試
            progressGui.BackColor := "0xe01717"  ; 深藍色背景
            progressGui.SetFont("s10 c0x42417a", "微軟正黑體")  ; 白色文字
            
            ; 添加文字標籤
            progressGui.Add("Text", "x10 y8", text)
            
            ; 獲取主螢幕的工作區域
            MonitorGetWorkArea(1, &mX, &mY, &mW, &mH)
            
            ; 計算視窗位置（右上角）
            guiWidth := 150
            guiHeight := 36
            xPos := mW - guiWidth - 20
            yPos := 40  ; 距離頂部 40 像素
            
            ; 顯示 GUI
            progressGui.Show("w" guiWidth " h" guiHeight " x" xPos " y" yPos " NoActivate")
            
            ; 設置透明度
            WinSetTransparent(250, progressGui)
            
            ; 保存視窗句柄
            this.hwnd := progressGui.Hwnd
            
            ; 保存 GUI 對象
            this.gui := progressGui
            
        } catch as e {
            ; 記錄錯誤到文件
            FileAppend "ProgressTip Show Error: " e.Message "`nStack: " e.Stack "`n", A_ScriptDir "\progress_tip_error.log"
        }
    }
    
    static Hide() {
        try {
            if (this.hwnd != 0) {
                if (this.gui is Gui) {
                    this.gui.Destroy()
                }
                this.hwnd := 0
            }
        } catch as e {
            ; 記錄錯誤到文件
            FileAppend "ProgressTip Hide Error: " e.Message "`nStack: " e.Stack "`n", A_ScriptDir "\progress_tip_error.log"
        }
    }
}

; ========== 初始化系統托盤圖標和選單 ==========
; 設置托盤圖標
if FileExist(A_ScriptDir "\translator.ico") {
    TraySetIcon(A_ScriptDir "\translator.ico")
} else {
    ; 使用默認圖標
}

; 創建選單回調函數
SelectClaude(ItemName, ItemPos, Menu) {
    global CurrentProvider := "Claude"
    
    ; 先取消所有勾選
    A_TrayMenu.Uncheck("使用 Claude API")
    A_TrayMenu.Uncheck("使用 OpenAI API")
    A_TrayMenu.Uncheck("使用 Akash API")
    
    ; 然後勾選當前選項
    A_TrayMenu.Check("使用 Claude API")
}

SelectOpenAI(ItemName, ItemPos, Menu) {
    global CurrentProvider := "OpenAI"
    
    ; 先取消所有勾選
    A_TrayMenu.Uncheck("使用 Claude API")
    A_TrayMenu.Uncheck("使用 OpenAI API")
    A_TrayMenu.Uncheck("使用 Akash API")
    
    ; 然後勾選當前選項
    A_TrayMenu.Check("使用 OpenAI API")
}

SelectAkash(ItemName, ItemPos, Menu) {
    global CurrentProvider := "Akash"
    
    ; 先取消所有勾選
    A_TrayMenu.Uncheck("使用 Claude API")
    A_TrayMenu.Uncheck("使用 OpenAI API")
    A_TrayMenu.Uncheck("使用 Akash API")
    
    ; 然後勾選當前選項
    A_TrayMenu.Check("使用 Akash API")
}

; 創建選單回調函數
SelectGemini(ItemName, ItemPos, Menu) {
    global CurrentProvider := "Gemini"
    
    ; 先取消所有勾選
    A_TrayMenu.Uncheck("使用 Claude API")
    A_TrayMenu.Uncheck("使用 OpenAI API")
    A_TrayMenu.Uncheck("使用 Akash API")
    A_TrayMenu.Uncheck("使用 Gemini API")
    
    ; 然後勾選當前選項
    A_TrayMenu.Check("使用 Gemini API")
}

; 直接添加到系統托盤選單
A_TrayMenu.Add("使用 Claude API", SelectClaude)
A_TrayMenu.Add("使用 OpenAI API", SelectOpenAI)
A_TrayMenu.Add("使用 Akash API", SelectAkash)
A_TrayMenu.Add("使用 Gemini API", SelectGemini)
A_TrayMenu.Add()  ; 分隔線

; 預設勾選 Akash
A_TrayMenu.Check("使用 Akash API")

; ========== 翻譯模式選單 ==========
; 創建翻譯模式選單
translateMenu := Menu()
translateMenu.Add("翻譯成英文", TranslateToEnglish)
translateMenu.Add("翻譯成繁體中文", TranslateToChinese)
translateMenu.Add("修正英文文法與錯字", CorrectEnglish)
translateMenu.Add("英文拼字檢查", SpellCheckEnglish)  

; ========== 快捷鍵設定 ==========
; 使用 CapsLock + S
*CapsLock Up::release_modifiers()

#HotIf GetKeyState('CapsLock', 'P')
*a::ShowTranslateMenu()
*s::ShowTranslateMenu()
*d::LookUp()
#HotIf

class double_tap_caps {
    static last := 0
    static __New() => SetCapsLockState('AlwaysOff')

    static Call() {
        if (A_TickCount - this.last < 250)
            this.toggle_caps()
            ,this.last := 0
        else this.last := A_TickCount
        KeyWait('CapsLock')
    }
    
    static toggle_caps() {
        state := GetKeyState('CapsLock', 'T') ? 'AlwaysOff' : 'AlwaysOn'
        SetCapsLockState(state)
    }
}

release_modifiers() {
    for key in ['Shift', 'Alt', 'Control', 'LWin', 'RWin']
        if GetKeyState(key) && !GetKeyState(key, 'P')
            Send('{' key ' Up}')
}

; 顯示翻譯模式選單的函數
ShowTranslateMenu() {
    ; 保存當前剪貼簿內容
    global SavedClipboard := A_Clipboard
    
    ; 嘗試複製選取的文字
    A_Clipboard := ""  ; 清空剪貼簿
    Send "^c"  ; 發送 Ctrl+C
    ClipWait(0.5)  ; 等待新內容，最多等 0.5 秒
    
    ; 檢查是否成功複製了文字
    if (A_Clipboard = "") {
        ; 還原剪貼簿內容
        A_Clipboard := SavedClipboard
        MsgBox("沒有選取文字！", "提示", "48")
        return
    }
    
    ; 保存選取的文字
    global SelectedText := A_Clipboard
    
    ; 還原剪貼簿內容
    A_Clipboard := SavedClipboard
    
    ; 獲取滑鼠位置
    MouseGetPos(&mouseX, &mouseY)
    
    ; 在滑鼠位置顯示選單
    translateMenu.Show(mouseX, mouseY)
}

; ========== 翻譯功能 ==========
; 翻譯成英文
TranslateToEnglish(ItemName, ItemPos, Menu) {
    Translate("en", "你是一位專業的翻譯員，請將接下來的中文句子翻譯為日常使用的英文對話，不需要太正式，但要確保表達清楚、自然，僅輸出翻譯結果。")
}
; 請將以下文字翻譯成自然流暢的英文。翻譯時應保持原文的意思，但不需要逐字翻譯，確保翻譯後的內容符合英文語言習慣
; 你是一位專業的翻譯員，請將接下來的中文句子翻譯為日常使用的英文對話，不需要太正式，但要確保表達清楚、自然。

; 翻譯成繁體中文
TranslateToChinese(ItemName, ItemPos, Menu) {
    Translate("zh-tw", "請將接下來的文本翻譯成正式的繁體中文。請確保用詞精確，適合用於專業報告或相關文檔，僅輸出翻譯結果。")
}
; 請將以下文字翻譯成正式的繁體中文。翻譯時應保持原文的意思，但不需要逐字翻譯，確保翻譯後的內容符合繁體中文語言習慣。
; 你是一位專業的醫療翻譯員，請將接下來的文本翻譯成正式的繁體中文。請確保用詞精確，適合用於醫療報告或相關文檔。

; 修正英文文法與錯字
CorrectEnglish(ItemName, ItemPos, Menu) {
    ; 使用更簡單的提示詞，避免特殊字符問題
    Translate("correct", "是一位專業的英文語言校對員，請檢查我接下來提供的英文句子，並修改文法或拼字錯誤。輸出修改後的句子，並簡單標註修改的地方。")
}
; 請修正以下英文文字的文法和拼寫錯誤。修正後，請列出所有錯誤及修正理由。
; 你是一位專業的英文語言校對員，請檢查我接下來提供的英文句子，並修改文法或拼字錯誤。輸出修改後的句子，並簡單標註修改的地方。

; 英文拼字檢查
SpellCheckEnglish(ItemName, ItemPos, Menu) {
    Translate("spell-check", "請檢查以下英文單字或片語的拼字。如果拼字正確，只需顯示「拼字正確」和對應的繁體中文翻譯。如果拼字錯誤，請列出可能正確的英文拼法和對應的繁體中文翻譯。不要列出假設性的錯誤情況。")
}
; 檢查以下英文字的拼字是否正確，顯示繁體中文翻譯，若是拼字錯誤，列出幾個可能正確的英文字。
; 請檢查以下英文單字或片語的拼字。如果拼字正確，只需顯示「拼字正確」和對應的繁體中文翻譯。如果拼字錯誤，請列出可能正確的英文拼法和對應的繁體中文翻譯。不要列出假設性的錯誤情況。

; 修改翻譯功能來處理剪貼簿還原
Translate(targetLanguage, prompt) {
    ; 使用全局變數中的提供者
    provider := CurrentProvider
    
    ; 保存要翻譯的文字
    textToTranslate := SelectedText
    
    ; 檢查 curl 是否存在
    if !CheckCurlExists() {
        MsgBox("系統中找不到 curl 命令。請安裝 curl 或使用其他方法。")
        return
    }
    
    ; 從 ini 檔讀取 API 設定
    apiKey := ReadApiKey(provider)
    model := ReadApiModel(provider)
    endpoint := ReadApiEndpoint(provider)
    version := ReadApiVersion(provider)
    
    if !apiKey || !endpoint {
        ; 還原剪貼簿內容
        A_Clipboard := SavedClipboard
        MsgBox("無法讀取 " provider " 的 API 設定。")
        return
    }
    
    ; 顯示進度提示
    try {
        ProgressTip.Show()
    } catch as e {
        MsgBox("Debug: ProgressTip 顯示失敗: " e.Message)  ; 調試訊息
    }
    
    ; 創建翻譯的請求內容
    jsonContent := CreateTranslationJson(provider, model, textToTranslate, prompt)
    
    ; 發送請求並獲取回應
    response := SendRequest(provider, endpoint, apiKey, version, jsonContent)
    
    ; 隱藏進度提示
    ProgressTip.Hide()
    
    ; 還原剪貼簿內容
    A_Clipboard := SavedClipboard
    
    ; 顯示回應
    if response {
        ; 根據翻譯模式設置標題
        title := ""
        if (targetLanguage = "en") {
            title := "翻譯成英文"
        } else if (targetLanguage = "zh-tw") {
            title := "翻譯成繁體中文"
        } else if (targetLanguage = "correct") {
            title := "英文文法修正"
        } else if (targetLanguage = "spell-check") {
            title := "英文拼字檢查"
        }
        
        ShowResponse(response, provider, title)
    }
}

/*
temperature 參數控制輸出的隨機性或多樣性:

- 低 temperature (0.0-0.3)：
  - 輸出更加一致、可預測
  - 更傾向於選擇最高概率的詞語
  - 適合需要準確性和可靠性的任務，如翻譯、摘要、事實查詢
  - 答案更加「安全」和保守

- 中等 temperature (0.4-0.7)：
  - 平衡創造性和一致性
  - 有一定的變化但仍保持連貫

- 高 temperature (0.8-1.0+)：
  - 產生更多樣化和意外的回應
  - 更適合創意寫作、腦力激盪、聊天機器人等應用
  - 可能會產生更有趣但不太可靠的內容

對於翻譯工具，0.3 是個很好的預設值，可獲得準確且一致的翻譯。
*/  

; 創建翻譯請求的 JSON
CreateTranslationJson(provider, model, textToTranslate, prompt) {
    ; 初始化基本 JSON 結構
    if (provider = "Claude") {
        jsonObj := Map(
            "model", model,
            "messages", [Map("role", "user", "content", prompt . "`n`n" . textToTranslate)],
            "max_tokens", 2000,
            "temperature", 0.3
        )
    } else if (provider = "OpenAI" || provider = "Akash") {
        jsonObj := Map(
            "model", model,
            "messages", [
                Map("role", "system", "content", prompt),
                Map("role", "user", "content", textToTranslate)
            ],
            "max_tokens", 2000,
            "temperature", 0.3
        )
    } else if (provider = "Gemini") {
        jsonObj := Map(
            "contents", [
                Map("role", "user", "parts", [Map("text", prompt . "`n`n" . textToTranslate)])
            ],
            "generationConfig", Map(
                "temperature", 0.3,
                "maxOutputTokens", 2000,
                "topP", 0.95,
                "topK", 40
            )
        )
    } else {
        MsgBox("不支援的 API 供應商: " provider)
        return ""
    }
    
    ; 使用 jsongo 轉換為 JSON 字符串
    return jsongo.Stringify(jsonObj, , "")
}

; 發送請求並獲取回應
SendRequest(provider, endpoint, apiKey, version, jsonContent) {
    ; 創建臨時文件
    jsonFile := A_Temp "\" provider "_request.json"
    Try FileDelete(jsonFile)
    
    ; 寫入 JSON 內容
    FileAppend jsonContent, jsonFile, "UTF-8-RAW"
    
    ; 準備回應文件
    responseFile := A_Temp "\" provider "_response.json"
    Try FileDelete(responseFile)
    
    ; 根據供應商準備 curl 命令
    curlCmd := 'curl -s -X POST "' endpoint '"'
    
    ; 添加標頭
    if (provider = "Claude") {
        curlCmd .= ' -H "Content-Type: application/json"'
            . ' -H "Accept: application/json"'
            . ' -H "x-api-key: ' apiKey '"'
            . ' -H "anthropic-version: ' version '"'
    } else if (provider = "OpenAI" || provider = "Akash") {
        curlCmd .= ' -H "Content-Type: application/json"'
            . ' -H "Accept: application/json"'
            . ' -H "Authorization: Bearer ' apiKey '"'
    } else if (provider = "Gemini") {
        ; Gemini API 金鑰是直接附加在 URL 上的
        ; 修改 endpoint 來包含 API 金鑰
        endpoint := StrReplace(endpoint, "{API_KEY}", apiKey)
        curlCmd := 'curl -s -X POST "' endpoint '"'
            . ' -H "Content-Type: application/json"'
    }
    
    ; 添加數據和輸出重定向
    curlCmd .= ' -d @"' jsonFile '"'
        . ' > "' responseFile '"'
    
    ; 執行 curl 命令
    RunWait A_ComSpec " /c " curlCmd, , "Hide"
    
    ; 檢查是否成功
    if !FileExist(responseFile) {
        MsgBox("請求失敗，沒有收到回應。")
        return ""
    }
    
    ; 讀取回應
    response := FileRead(responseFile, "UTF-8")
    
    ; 清理臨時文件
    FileDelete(jsonFile)
    ; 保留回應文件用於除錯
    
    return response
}

ExtractResponseText(response, provider) {
    try {
        ; 使用 jsongo 解析 JSON 回應
        jsonObj := jsongo.Parse(response)
        
        ; 根據不同提供商提取文本
        if (provider = "Claude") {
            if (jsonObj.Has("content")) {
                for i, item in jsonObj["content"] {
                    if (item.Has("text")) {
                        return item["text"]
                    }
                }
            }
        } else if (provider = "OpenAI" || provider = "Akash") {
            if (jsonObj.Has("choices")) {
                for i, choice in jsonObj["choices"] {
                    if (choice.Has("message") && choice["message"].Has("content")) {
                        return choice["message"]["content"]
                    }
                }
            }
        } else if (provider = "Gemini") {
            if (jsonObj.Has("candidates") && jsonObj["candidates"].Length > 0) {
                if (jsonObj["candidates"][1].Has("content") && 
                    jsonObj["candidates"][1]["content"].Has("parts") && 
                    jsonObj["candidates"][1]["content"]["parts"].Length > 0) {
                    return jsonObj["candidates"][1]["content"]["parts"][1]["text"]
                }
            }
        }
        
        ; 如果提取失敗，記錄錯誤
        FileAppend("無法解析回應：`n" . response . "`n", A_ScriptDir . "\response_error.log", "UTF-8")
        return "無法識別回應格式。錯誤已記錄到 response_error.log 文件。"
    } catch Error as e {
        ; 發生異常時，記錄詳細錯誤信息
        errorMsg := "提取文字時發生錯誤: " . e.Message . "`n在第 " . e.Line . " 行`n"
        FileAppend(errorMsg . "原始回應：`n" . response, A_ScriptDir . "\extract_error.log", "UTF-8")
        
        return "提取文字內容時發生錯誤。詳細信息已記錄到 extract_error.log 文件。"
    }
}

ShowResponse(response, provider, title := "", mouseX := 0, mouseY := 0) {
    ; 獲取當前使用的模型名稱
    model := ReadApiModel(provider)
    
    ; 創建 GUI 標題
    guiTitle := provider " [" model "] - " title
    
    ; 創建 GUI，添加最小尺寸限制
    responseGui := Gui("+Resize MinSize400x300", guiTitle)  ; 添加 MinSize 限制
    responseGui.BackColor := "0xe4D299"  ; Tiffany Blue 背景色
    ; responseGui.BackColor := "0x81D8D0"  ; Tiffany Blue 背景色
    responseGui.SetFont("s15", "微軟正黑體")
    
    ; 提取文字
    extractedText := ExtractResponseText(response, provider)

    ; 設置標籤文字顏色
    ; responseGui.SetFont("s15 c000000")  ; 黑色文字
    responseGui.SetFont("s15 cb28656")  ; 黑色文字
    
    ; 添加原始文字標籤和編輯框
    resultLabel := responseGui.AddText("xm w200", "處理結果:")

    ; 設置編輯框的字體和顏色
    responseGui.SetFont("s15 cb28656")  ; 白色文字
    ; responseGui.SetFont("s15 cFFFFFF")  ; 白色文字
    translatedBox := responseGui.AddEdit("xm y+20 w600 h200 ReadOnly")
    translatedBox.Value := extractedText
    translatedBox.Opt("+Backgrounde1ddc3")  ; 深色背景
    ; translatedBox.Opt("+Background1A1A1A")  ; 深色背景


    ; 重新設置標籤文字顏色
    ; responseGui.SetFont("s15 c000000")  ; 黑色文字
    responseGui.SetFont("s15 cb28656")  ; 黑色文字

    ; 添加處理結果標籤和編輯框
    originalLabel := responseGui.AddText("xm y+10 w200", "原始文字:")
    ; 設置編輯框的字體和顏色
    ; responseGui.SetFont("s15 cFFFFFF")  ; 白色文字
    responseGui.SetFont("s15 cb28656")  ; 白色文字
    originalBox := responseGui.AddEdit("xm y+15 w600 h150 ReadOnly")
    originalBox.Value := SelectedText
    originalBox.Opt("+Backgrounde1ddc3")  ; 深色背景

    ; 重設回默認字體用於按鈕
    responseGui.SetFont("s15")

    ; 添加按鈕
    copyBtn := responseGui.AddButton("xm y+10 w100", "複製結果")
    copyBtn.OnEvent("Click", (*) => CopyTranslation(extractedText))
    
    closeBtn := responseGui.AddButton("x+10 w100", "關閉")
    closeBtn.OnEvent("Click", (*) => responseGui.Destroy())
    
    ; 保存控件引用為 GUI 的屬性
    responseGui.originalLabel := originalLabel
    responseGui.originalBox := originalBox
    responseGui.resultLabel := resultLabel
    responseGui.translatedBox := translatedBox
    responseGui.copyBtn := copyBtn
    responseGui.closeBtn := closeBtn
    
    ; 添加大小調整事件處理
    responseGui.OnEvent("Size", GuiResize)
    
    ; 如果沒有提供滑鼠位置，則獲取當前位置
    if (mouseX = 0 && mouseY = 0) {
        MouseGetPos(&mouseX, &mouseY)
    }
    ; 設定視窗寬高
    winWidth := 900
    winHeight := 870

    ; 顯示 GUI，在滑鼠位置
    responseGui.Show(Format("w{1} h{2} x{3} y{4}", winWidth, winHeight, mouseX, mouseY))
    ; responseGui.Show("w620 h450 x775 y394")
}
; GUI 大小調整處理函數
GuiResize(thisGui, MinMax, Width, Height) {
    if MinMax = -1  ; 視窗最小化
        return
    
    ; 計算可用空間
    availableHeight := Height - 75
    
    ; 計算各區域高度
    originalHeight := Floor(availableHeight * 0.3)
    translatedHeight := Floor(availableHeight * 0.7) - 60
    
    ; 計算寬度
    controlWidth := Width - 20
    
    ; 調整原始文字區域
    thisGui.resultLabel.Move(10, 10)
    thisGui.translatedBox.Move(10, 40, controlWidth, translatedHeight)
    
    ; 調整處理結果區域
    labelY := translatedHeight + 50
    thisGui.originalLabel.Move(10, labelY)
    thisGui.originalBox.Move(10, labelY + 30, controlWidth, originalHeight)
    
    ; 調整按鈕位置
    buttonY := Height - 40
    btnWidth := 100
    btn1X := (Width - (btnWidth * 2 + 20)) // 2
    btn2X := btn1X + btnWidth + 20
    
    thisGui.copyBtn.Move(btn1X, buttonY, btnWidth, 30)
    thisGui.closeBtn.Move(btn2X, buttonY, btnWidth, 30)
    
    ; 強制重繪
    try WinRedraw(thisGui)
}

; 複製翻譯結果到剪貼簿
CopyTranslation(text) {
    A_Clipboard := text
    ToolTip("已複製結果到剪貼簿！", , , 1)
    SetTimer () => ToolTip("", , , 1), -1000  ; 1秒後自動消失
}

; 檢查系統是否有 curl
CheckCurlExists() {
    shell := ComObject("WScript.Shell")
    try {
        exec := shell.Exec("curl --version")
        output := exec.StdOut.ReadAll()
        return InStr(output, "curl") > 0
    } catch {
        return false
    }
}

; 從 ini 檔讀取 API 設定
ReadApiSetting(provider, key, defaultValue := "") {
    iniFile := A_ScriptDir "\api.ini"
    
    ; 檢查 ini 檔是否存在
    if !FileExist(iniFile) {
        ; 如果不存在，創建樣板 ini 檔
        CreateTemplateIniFile(iniFile)
        MsgBox("已創建 api.ini 樣板檔案。請填入您的 API 金鑰後再試。")
        return defaultValue
    }
    
    ; 讀取指定供應商的設定
    value := IniRead(iniFile, provider, key, defaultValue)
    return value
}

; 讀取 API 金鑰
ReadApiKey(provider) {
    apiKey := ReadApiSetting(provider, "ApiKey", "")
    
    ; 檢查 API 金鑰是否有效
    if (apiKey = "" || InStr(apiKey, "你的") || InStr(apiKey, "your_")) {
        MsgBox("請在 api.ini 中設定有效的 " provider " API 金鑰。")
        return ""
    }
    
    return apiKey
}

; 讀取 API 模型
ReadApiModel(provider) {
    defaultModels := Map(
        "Claude", "claude-3-haiku-20240307",
        "OpenAI", "gpt-4o",
        "Akash", "Meta-Llama-3-1-8B-Instruct-FP8",
        "Gemini", "gemini-1.5-pro"
    )
    
    model := ReadApiSetting(provider, "Model", defaultModels.Has(provider) ? defaultModels[provider] : "")
    return model
}

; 讀取 API 端點
ReadApiEndpoint(provider) {
    defaultEndpoints := Map(
        "Claude", "https://api.anthropic.com/v1/messages",
        "OpenAI", "https://api.openai.com/v1/chat/completions",
        "Akash", "https://chatapi.akash.network/api/v1/chat/completions",
        "Gemini", "https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}"
    )
    
    endpoint := ReadApiSetting(provider, "Endpoint", defaultEndpoints.Has(provider) ? defaultEndpoints[provider] : "")
    
    ; 如果是 Gemini，需要替換 {MODEL} 為實際模型名稱
    if (provider = "Gemini") {
        model := ReadApiModel(provider)
        endpoint := StrReplace(endpoint, "{MODEL}", model)
    }
    
    return endpoint
}

; 讀取 API 版本
ReadApiVersion(provider) {
    defaultVersions := Map(
        "Claude", "2023-06-01",
        "OpenAI", "",
        "Akash", ""
    )
    
    version := ReadApiSetting(provider, "Version", defaultVersions.Has(provider) ? defaultVersions[provider] : "")
    return version
}

; 創建樣板 ini 檔
; 創建樣板 ini 檔
CreateTemplateIniFile(filePath) {
    content := "[Claude]`n"
        . "ApiKey=sk-ant-api03-你的Claude金鑰`n"
        . "Model=claude-3-haiku-20240307`n"
        . "Endpoint=https://api.anthropic.com/v1/messages`n"
        . "Version=2023-06-01`n"
        . "`n"
        . "[OpenAI]`n"
        . "ApiKey=sk-你的OpenAI金鑰`n"
        . "Model=gpt-4o`n"
        . "Endpoint=https://api.openai.com/v1/chat/completions`n"
        . "Version=`n"
        . "`n"
        . "[Akash]`n"
        . "ApiKey=sk-你的Akash金鑰`n"
        . "Model=Meta-Llama-3-1-8B-Instruct-FP8`n"
        . "Endpoint=https://chatapi.akash.network/api/v1/chat/completions`n"
        . "Version=`n"
        . "`n"
        . "[Gemini]`n"
        . "ApiKey=你的Gemini金鑰`n"
        . "Model=gemini-1.5-pro`n"
        . "Endpoint=https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}`n"
        . "Version=`n"
    
    file := FileOpen(filePath, "w", "UTF-8")
    if file {
        file.Write(content)
        file.Close()
        return true
    }
    return false
}

LookUp()
{
    Sleep 300
    a := A_Clipboard
    A_Clipboard := ""
    Send "^c"
    Sleep 300
    b := A_Clipboard
    if (StrLen(b) > 0 and StrLen(b) < 20)
    {
        
        MouseGetPos(&mouseX, &mouseY)
        Run '"C:\Green software\GoldenDict\GoldenDict.exe" "' b '"'
        Sleep 800
        WinWait "ahk_class Qt5QWindowIcon ahk_exe GoldenDict.exe",, 5
        WinMove mouseX+150, mouseY, 822, 672, "ahk_class Qt5QWindowIcon ahk_exe GoldenDict.exe"
        WinActivate "ahk_class Qt5QWindowIcon ahk_exe GoldenDict.exe"
        
    }
    A_Clipboard := ""
    if (StrLen(b) = 0)
    {
        A_Clipboard := a   ; 還原剪貼簿內容
        MsgBox("沒有選取文字！", "提示", "48")
        return
    }
    a := ""
    b := ""
    return
}