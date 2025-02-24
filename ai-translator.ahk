#Requires AutoHotkey v2.0
#SingleInstance Force

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

; 直接添加到系統托盤選單
A_TrayMenu.Add("使用 Claude API", SelectClaude)
A_TrayMenu.Add("使用 OpenAI API", SelectOpenAI)
A_TrayMenu.Add("使用 Akash API", SelectAkash)
A_TrayMenu.Add()  ; 分隔線

; 預設勾選 Akash
A_TrayMenu.Check("使用 Akash API")

; ========== 翻譯模式選單 ==========
; 創建翻譯模式選單
translateMenu := Menu()
translateMenu.Add("翻譯成英文", TranslateToEnglish)
translateMenu.Add("翻譯成繁體中文", TranslateToChinese)
translateMenu.Add("修正英文文法與錯字", CorrectEnglish)

; ========== 快捷鍵設定 ==========
; 使用 CapsLock 鍵顯示翻譯模式選單（替代原來的 F1）
CapsLock::ShowTranslateMenu()
; 添加 Shift+CapsLock 組合鍵來切換 CapsLock 狀態
+CapsLock::SetCapsLockState(!GetKeyState("CapsLock", "T"))

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
    Translate("en", "請將以下文字翻譯成自然流暢的英文。翻譯時應保持原文的意思，但不需要逐字翻譯，確保翻譯後的內容符合英文語言習慣。")
}

; 翻譯成繁體中文
TranslateToChinese(ItemName, ItemPos, Menu) {
    Translate("zh-tw", "請將以下文字翻譯成正式的繁體中文。翻譯時應保持原文的意思，但不需要逐字翻譯，確保翻譯後的內容符合繁體中文語言習慣。")
}

; 修正英文文法與錯字
CorrectEnglish(ItemName, ItemPos, Menu) {
    ; 使用更簡單的提示詞，避免特殊字符問題
    Translate("correct", "請修正以下英文文字的文法和拼寫錯誤。修正後，請列出所有錯誤及修正理由。")
}

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
        }
        
        ShowResponse(response, provider, title)
    }
}

; 創建翻譯請求的 JSON
CreateTranslationJson(provider, model, textToTranslate, prompt) {
    ; 將所有內容透過臨時文件處理，避免字串處理問題
    
    ; 先寫出基礎 JSON 模板
    if (provider = "Claude") {
        jsonTemplate := '{"model":"MODEL_PLACEHOLDER","messages":[{"role":"user","content":"PROMPT_PLACEHOLDER\n\nTEXT_PLACEHOLDER"}],"max_tokens":2000}'
    } else if (provider = "OpenAI" || provider = "Akash") {
        jsonTemplate := '{"model":"MODEL_PLACEHOLDER","messages":[{"role":"system","content":"PROMPT_PLACEHOLDER"},{"role":"user","content":"TEXT_PLACEHOLDER"}],"max_tokens":2000,"temperature":0.3}'
    } else {
        MsgBox("不支援的 API 供應商: " provider)
        return ""
    }
    
    ; 將模板寫入臨時文件
    templateFile := A_Temp "\json_template.json"
    Try FileDelete(templateFile)
    FileAppend jsonTemplate, templateFile, "UTF-8-RAW"
    
    ; 讀取模板
    jsonTemplate := FileRead(templateFile, "UTF-8-RAW")
    
    ; 替換佔位符
    jsonTemplate := StrReplace(jsonTemplate, "MODEL_PLACEHOLDER", model)
    
    ; 將提示詞和翻譯文本寫入臨時文件
    promptFile := A_Temp "\prompt.txt"
    textFile := A_Temp "\text.txt"
    
    Try FileDelete(promptFile)
    Try FileDelete(textFile)
    
    FileAppend prompt, promptFile, "UTF-8-RAW"
    FileAppend textToTranslate, textFile, "UTF-8-RAW"
    
    ; 讀取提示詞和翻譯文本
    promptContent := FileRead(promptFile, "UTF-8-RAW")
    textContent := FileRead(textFile, "UTF-8-RAW")
    
    ; 將換行符替換為 \n
    promptContent := StrReplace(promptContent, "`r`n", "\n")
    promptContent := StrReplace(promptContent, "`n", "\n")
    promptContent := StrReplace(promptContent, "`r", "\n")
    
    textContent := StrReplace(textContent, "`r`n", "\n")
    textContent := StrReplace(textContent, "`n", "\n")
    textContent := StrReplace(textContent, "`r", "\n")
    
    ; 處理其他需要轉義的字符
    promptContent := StrReplace(promptContent, "\", "\\")
    promptContent := StrReplace(promptContent, '"', '\"')
    
    textContent := StrReplace(textContent, "\", "\\")
    textContent := StrReplace(textContent, '"', '\"')
    
    ; 替換佔位符
    jsonTemplate := StrReplace(jsonTemplate, "PROMPT_PLACEHOLDER", promptContent)
    jsonTemplate := StrReplace(jsonTemplate, "TEXT_PLACEHOLDER", textContent)
    
    ; 寫入最終 JSON 文件
    jsonFile := A_Temp "\final_request.json"
    Try FileDelete(jsonFile)
    FileAppend jsonTemplate, jsonFile, "UTF-8-RAW"
    
    ; 讀取並返回最終 JSON
    return FileRead(jsonFile, "UTF-8-RAW")
}

; 發送請求並獲取回應
SendRequest(provider, endpoint, apiKey, version, jsonContent) {
    ; 創建臨時文件
    jsonFile := A_Temp "\" provider "_request.json"
    Try FileDelete(jsonFile)
    
    ; 寫入 JSON 內容
    file := FileOpen(jsonFile, "w", "UTF-8-RAW")
    if !file {
        MsgBox("無法創建請求文件。")
        return ""
    }
    file.Write(jsonContent)
    file.Close()
    
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
        ; 將回應寫入臨時文件，以便更好地處理
        responseFile := A_Temp "\response_extract.json"
        Try FileDelete(responseFile)
        FileAppend response, responseFile, "UTF-8"
        response := FileRead(responseFile, "UTF-8")
        
        ; 初始化提取的文本
        extractedText := ""
        
        if (provider = "Claude") {
            ; Claude 回應格式處理
            ; 尋找 "text": 欄位
            if InStr(response, '"text":') {
                ; 分段處理 JSON 字串
                startPos := InStr(response, '"text":') + 7  ; 7 = 長度 '"text":'
                
                ; 找到第一個引號的位置
                quotePos := InStr(response, '"', , startPos) + 1
                
                ; 找到封閉引號位置（需考慮轉義引號）
                closePos := quotePos
                escapeCount := 0
                
                loop {
                    ; 找下一個引號位置
                    nextQuote := InStr(response, '"', , closePos)
                    if (nextQuote = 0) {
                        break  ; 找不到更多引號，跳出循環
                    }
                    
                    ; 檢查引號前是否有奇數個反斜線（如果是，則為轉義引號）
                    backslashCount := 0
                    checkPos := nextQuote - 1
                    while (checkPos > 0 && SubStr(response, checkPos, 1) = "\") {
                        backslashCount += 1
                        checkPos -= 1
                    }
                    
                    if (Mod(backslashCount, 2) = 0) {
                        ; 偶數個反斜線表示這是真正的結束引號
                        closePos := nextQuote
                        break
                    } else {
                        ; 奇數個反斜線表示這是轉義引號，繼續尋找
                        closePos := nextQuote + 1
                    }
                }
                
                if (closePos > quotePos) {
                    extractedText := SubStr(response, quotePos, closePos - quotePos)
                    
                    ; 處理 JSON 轉義序列
                    extractedText := ProcessJsonEscapes(extractedText, provider)
                }
            }
        } else if (provider = "OpenAI" || provider = "Akash") {
            ; OpenAI/Akash 回應格式處理
            ; 尋找 "content": 欄位
            if InStr(response, '"content":') {
                ; 分段處理 JSON 字串
                startPos := InStr(response, '"content":') + 10  ; 10 = 長度 '"content":'
                
                ; 找到第一個引號的位置
                quotePos := InStr(response, '"', , startPos) + 1
                
                ; 找到封閉引號位置（需考慮轉義引號）
                closePos := quotePos
                escapeCount := 0
                
                loop {
                    ; 找下一個引號位置
                    nextQuote := InStr(response, '"', , closePos)
                    if (nextQuote = 0) {
                        break  ; 找不到更多引號，跳出循環
                    }
                    
                    ; 檢查引號前是否有奇數個反斜線（如果是，則為轉義引號）
                    backslashCount := 0
                    checkPos := nextQuote - 1
                    while (checkPos > 0 && SubStr(response, checkPos, 1) = "\") {
                        backslashCount += 1
                        checkPos -= 1
                    }
                    
                    if (Mod(backslashCount, 2) = 0) {
                        ; 偶數個反斜線表示這是真正的結束引號
                        closePos := nextQuote
                        break
                    } else {
                        ; 奇數個反斜線表示這是轉義引號，繼續尋找
                        closePos := nextQuote + 1
                    }
                }
                
                if (closePos > quotePos) {
                    extractedText := SubStr(response, quotePos, closePos - quotePos)
                    
                    ; 處理 JSON 轉義序列
                    extractedText := ProcessJsonEscapes(extractedText, provider)
                }
            }
        }
        
        ; 如果提取失敗，嘗試寫入錯誤日誌並返回提示
        if (extractedText = "") {
            ; 寫入錯誤日誌文件
            errorLogFile := A_ScriptDir "\response_error.log"
            FileAppend "無法解析回應：`n" response "`n", errorLogFile, "UTF-8"
            
            return "無法識別回應格式。錯誤已記錄到 response_error.log 文件。"
        }
        
        ; 刪除臨時文件
        FileDelete(responseFile)
        
        return extractedText
    } catch Error as e {
        ; 發生異常時，記錄詳細錯誤信息
        errorMsg := "提取文字時發生錯誤: " e.Message "`n在第 " e.Line " 行`n"
        FileAppend errorMsg "原始回應：`n" response, A_ScriptDir "\extract_error.log", "UTF-8"
        
        return "提取文字內容時發生錯誤。詳細信息已記錄到 extract_error.log 文件。"
    }
}

; 處理 JSON 轉義序列的輔助函數，根據不同提供商調整處理方式
ProcessJsonEscapes(text, provider) {
    ; 處理常見的 JSON 轉義序列
    processedText := text
    
    ; 處理換行符
    processedText := StrReplace(processedText, "\n", "`n")
    processedText := StrReplace(processedText, "\r", "`r")
    
    ; 處理引號和其他特殊字符
    processedText := StrReplace(processedText, '\"', '"')
    processedText := StrReplace(processedText, "\t", "`t")
    processedText := StrReplace(processedText, "\b", "`b")
    processedText := StrReplace(processedText, "\f", "`f")
    
    ; 特別處理 Akash API 的多餘反斜線問題
    if (provider = "Akash") {
        ; 清除段落結尾的單獨反斜線
        processedText := RegExReplace(processedText, "\\(\r\n|\r|\n)", "$1")
        processedText := RegExReplace(processedText, "\\$", "")  ; 處理文本結尾的反斜線
        
        ; 修正段落間可能出現的連續反斜線 + 換行
        processedText := RegExReplace(processedText, "\\\\(\r\n|\r|\n)", "$1")
        
        ; 針對 Akash 的多餘反斜線，使用多次簡單替換而非複雜正則
        ; 先處理段落結尾反斜線
        processedText := StrReplace(processedText, "\", "")
    } else {
        ; 非 Akash 提供商的標準處理
        processedText := StrReplace(processedText, "\\", "\")
    }
    
    ; 處理 Unicode 轉義序列 \uXXXX
    pos := 1
    while (pos := InStr(processedText, "\u", false, pos)) {
        ; 確保有足夠的字符
        if (pos + 5 <= StrLen(processedText)) {
            ; 提取 4 位十六進制
            hexCode := SubStr(processedText, pos + 2, 4)
            
            ; 嘗試轉換為字符
            try {
                ; 將十六進制轉換為十進制
                charCode := Integer("0x" hexCode)
                
                ; 轉換為 UTF-16 字符
                char := Chr(charCode)
                
                ; 替換轉義序列
                processedText := StrReplace(processedText, "\u" hexCode, char, , 1)
            } catch {
                ; 如果轉換失敗，跳過此轉義序列
                pos += 6
            }
        } else {
            ; 不夠長，退出循環
            break
        }
    }
    
    return processedText
}

; 根據供應商處理並顯示回應
ShowResponse(response, provider, title := "") {
    ; 獲取當前使用的模型名稱
    model := ReadApiModel(provider)
    
    ; 創建 GUI 標題
    guiTitle := provider " [" model "] - " title
    
    ; 創建 GUI，添加最小尺寸限制
    responseGui := Gui("+Resize MinSize400x300", guiTitle)  ; 添加 MinSize 限制
    responseGui.BackColor := "0x81D8D0"  ; Tiffany Blue 背景色
    responseGui.SetFont("s15", "微軟正黑體")
    
    ; 提取文字
    extractedText := ExtractResponseText(response, provider)

    ; 設置標籤文字顏色
    responseGui.SetFont("s15 c000000")  ; 黑色文字
    
    ; 添加原始文字標籤和編輯框
    originalLabel := responseGui.AddText("xm w200", "原始文字:")

    ; 設置編輯框的字體和顏色
    responseGui.SetFont("s15 cFFFFFF")  ; 白色文字
    originalBox := responseGui.AddEdit("xm y+20 w600 h150 ReadOnly")
    originalBox.Value := SelectedText
    originalBox.Opt("+Background1A1A1A")  ; 深色背景

    ; 重新設置標籤文字顏色
    responseGui.SetFont("s15 c000000")  ; 黑色文字

    ; 添加處理結果標籤和編輯框
    resultLabel := responseGui.AddText("xm y+10 w200", "處理結果:")
    ; 設置編輯框的字體和顏色
    responseGui.SetFont("s15 cFFFFFF")  ; 白色文字
    translatedBox := responseGui.AddEdit("xm y+15 w600 h200 ReadOnly")
    translatedBox.Value := extractedText
    translatedBox.Opt("+Background1A1A1A")  ; 深色背景

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
    
    ; 顯示 GUI
    responseGui.Show("w620 h450")
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
    thisGui.originalLabel.Move(10, 10)
    thisGui.originalBox.Move(10, 40, controlWidth, originalHeight)
    
    ; 調整處理結果區域
    labelY := originalHeight + 50
    thisGui.resultLabel.Move(10, labelY)
    thisGui.translatedBox.Move(10, labelY + 30, controlWidth, translatedHeight)
    
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
        "Akash", "Meta-Llama-3-1-8B-Instruct-FP8"
    )
    
    model := ReadApiSetting(provider, "Model", defaultModels.Has(provider) ? defaultModels[provider] : "")
    return model
}

; 讀取 API 端點
ReadApiEndpoint(provider) {
    defaultEndpoints := Map(
        "Claude", "https://api.anthropic.com/v1/messages",
        "OpenAI", "https://api.openai.com/v1/chat/completions",
        "Akash", "https://chatapi.akash.network/api/v1/chat/completions"
    )
    
    endpoint := ReadApiSetting(provider, "Endpoint", defaultEndpoints.Has(provider) ? defaultEndpoints[provider] : "")
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
    
    file := FileOpen(filePath, "w", "UTF-8")
    if file {
        file.Write(content)
        file.Close()
        return true
    }
    return false
}

