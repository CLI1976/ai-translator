#Requires AutoHotkey v2.0
#SingleInstance Force

; 按F1發送請求給Claude API
F1::SendCurlRequest()

; 使用curl發送請求，從ini讀取API金鑰
SendCurlRequest() {
    ; 從ini檔讀取API金鑰
    apiKey := ReadApiKey("Claude")
    if !apiKey {
        MsgBox("無法讀取Claude API金鑰。請確認api.ini檔案設定正確。")
        return
    }
    
    ; 檢查curl是否存在
    if !CheckCurlExists() {
        MsgBox("系統中找不到curl命令。請安裝curl或使用其他方法。")
        return
    }
    
    ; 創建請求JSON文件 - 正確使用FileOpen
    jsonFile := A_Temp "\claude_request.json"
    Try FileDelete(jsonFile)
    
    ; 正確打開、寫入和關閉文件 
    file := FileOpen(jsonFile, "w", "UTF-8-RAW")
    if file {
        file.Write('{"model":"claude-3-haiku-20240307","messages":[{"role":"user","content":"哈囉，你好？請用繁體中文回答。"}],"max_tokens":1000}')
        file.Close()
    } else {
        MsgBox("無法創建JSON文件！")
        return
    }
    
    ; 準備curl命令
    responseFile := A_Temp "\claude_response.json"
    Try FileDelete(responseFile)
    
    curlCmd := 'curl -s -X POST "https://api.anthropic.com/v1/messages"'
        . ' -H "Content-Type: application/json"'
        . ' -H "Accept: application/json"'
        . ' -H "x-api-key: ' apiKey '"'
        . ' -H "anthropic-version: 2023-06-01"'
        . ' -d @"' jsonFile '"'
        . ' > "' responseFile '"'
    
    ; 執行curl命令
    RunWait A_ComSpec " /c " curlCmd, , "Hide"
    
    ; 讀取回應
    if FileExist(responseFile) {
        response := FileRead(responseFile, "UTF-8")
        ShowResponse(response)
    } else {
        MsgBox "回應檔案未找到，請求可能失敗。"
    }
    
    ; 保留回應文件用於除錯
}

; 從ini檔讀取API金鑰
ReadApiKey(provider) {
    iniFile := A_ScriptDir "\api.ini"
    
    ; 檢查ini檔是否存在
    if !FileExist(iniFile) {
        ; 如果不存在，創建樣板ini檔
        CreateTemplateIniFile(iniFile)
        MsgBox("已創建api.ini樣板檔案。請填入您的API金鑰後再試。")
        return ""
    }
    
    ; 讀取指定供應商的API金鑰
    apiKey := IniRead(iniFile, provider, "ApiKey", "")
    
    ; 檢查API金鑰是否有效
    if (apiKey = "" || InStr(apiKey, "your_api_key_here")) {
        MsgBox("請在api.ini中設定有效的" provider " API金鑰。")
        return ""
    }
    
    return apiKey
}

; 創建樣板ini檔
CreateTemplateIniFile(filePath) {
    content := "[Claude]`n"
        . "ApiKey=your_claude_api_key_here`n"
        . "Model=claude-3-haiku-20240307`n"
        . "`n"
        . "[OpenAI]`n"
        . "ApiKey=your_openai_api_key_here`n"
        . "Model=gpt-4o`n"
        . "`n"
        . "[Gemini]`n"
        . "ApiKey=your_gemini_api_key_here`n"
        . "Model=gemini-1.5-pro`n"
        . "`n"
        . "[Mistral]`n"
        . "ApiKey=your_mistral_api_key_here`n"
        . "Model=mistral-large-latest`n"
    
    file := FileOpen(filePath, "w", "UTF-8")
    if file {
        file.Write(content)
        file.Close()
        return true
    }
    return false
}

; 檢查系統是否有curl
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

; 在GUI中顯示回應
ShowResponse(response) {
    ; 創建GUI
    responseGui := Gui("", "Claude 回應")
    responseGui.SetFont("s12", "微軟正黑體")
    
    ; 添加顯示區域
    responseGui.AddText("w100", "回應內容:")
    responseBox := responseGui.AddEdit("xm w600 h340 ReadOnly")
    responseBox.Value := response
    
    ; 嘗試提取文字欄位
    try {
        ; 使用基本字串操作尋找文字欄位
        textStart := InStr(response, '"text":"') + 8
        if (textStart > 8) {
            textEnd := InStr(response, '"', , textStart)
            if (textEnd > textStart) {
                extractedText := SubStr(response, textStart, textEnd - textStart)
                
                ; 在另一個框中顯示提取的文字
                responseGui.AddText("xm y+20 w140", "提取的文字:")
                extractedBox := responseGui.AddEdit("xm y+5 w600 h150 ReadOnly")
                extractedBox.Value := extractedText
            }
        }
    }
    
    ; 添加關閉按鈕
    closeBtn := responseGui.AddButton("xm w100", "關閉")
    closeBtn.OnEvent("Click", (*) => responseGui.Destroy())
    
    ; 顯示GUI
    responseGui.Show("w620 h650")
}