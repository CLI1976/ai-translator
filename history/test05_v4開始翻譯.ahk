#Requires AutoHotkey v2.0
#SingleInstance Force

; 快捷鍵設定
F1::TranslateClipboard("Claude")  ; 按 F1 使用 Claude 翻譯剪貼簿內容
F2::TranslateClipboard("OpenAI")  ; 按 F2 使用 OpenAI 翻譯剪貼簿內容
F3::TranslateClipboard("Akash")   ; 按 F3 使用 Akash 翻譯剪貼簿內容

; 翻譯剪貼簿內容
TranslateClipboard(provider := "Claude") {
    ; 檢查剪貼簿是否有內容
    clipText := A_Clipboard
    if (clipText = "") {
        MsgBox("剪貼簿內容為空，請先複製要翻譯的文字。")
        return
    }
    
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
        MsgBox("無法讀取 " provider " 的 API 設定。")
        return
    }
    
    ; 顯示處理中訊息
    MsgBox("正在翻譯剪貼簿內容，請稍候...", "翻譯處理中", "T2")
    
    ; 創建翻譯的請求內容
    jsonContent := CreateTranslationJson(provider, model, clipText)
    
    ; 發送請求並獲取回應
    response := SendRequest(provider, endpoint, apiKey, version, jsonContent)
    
    ; 顯示回應
    if response {
        ShowResponse(response, provider)
    }
}

; 創建翻譯請求的 JSON
CreateTranslationJson(provider, model, textToTranslate) {
    ; 將文本寫入臨時文件，以處理特殊字符
    tempFile := A_Temp "\text_to_translate.txt"
    Try FileDelete(tempFile)  ; 使用 Try 避免檔案不存在時出錯
    FileAppend textToTranslate, tempFile, "UTF-8"
    FileEncoding "UTF-8"
    translateText := FileRead(tempFile)
    Try FileDelete(tempFile)  ; 清理臨時文件
    
    ; 根據不同供應商創建 JSON
    if (provider = "Claude") {
        ; 將翻譯文本和指令寫入文件
        contentFile := A_Temp "\claude_content.json"
        Try FileDelete(contentFile)  ; 使用 Try 避免檔案不存在時出錯
        content := Format('{"model":"{1}","messages":[{"role":"user","content":"你是一位專業的翻譯員，請將接下來的文本翻譯成正式的繁體中文。\n\n{2}"}],"max_tokens":2000}', model, translateText)
        FileAppend content, contentFile, "UTF-8-RAW"
        return FileRead(contentFile, "UTF-8-RAW")
    } else if (provider = "OpenAI" || provider = "Akash") {
        ; 將翻譯文本和指令寫入文件
        contentFile := A_Temp "\openai_content.json"
        Try FileDelete(contentFile)  ; 使用 Try 避免檔案不存在時出錯
        content := Format('{"model":"{1}","messages":[{"role":"system","content":"你是一位專業的翻譯員，請將接下來的文本翻譯成正式的繁體中文。"},{"role":"user","content":"{2}"}],"max_tokens":2000,"temperature":0.3}', model, translateText)
        FileAppend content, contentFile, "UTF-8-RAW"
        return FileRead(contentFile, "UTF-8-RAW")
    } else {
        MsgBox("不支援的 API 供應商: " provider)
        return ""
    }
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

; 從不同供應商的回應中提取文字
ExtractResponseText(response, provider) {
    ; 檢查是否包含錯誤
    if InStr(response, '"error"') {
        return "發生錯誤: " response
    }
    
    try {
        if (provider = "Claude") {
            ; Claude 回應格式: content[0].text
            textStart := InStr(response, '"text":"') + 8
            if (textStart > 8) {
                textEnd := InStr(response, '"', , textStart)
                if (textEnd > textStart) {
                    extractedText := SubStr(response, textStart, textEnd - textStart)
                    ; 處理轉義字符
                    extractedText := StrReplace(extractedText, "\n", "`n")
                    extractedText := StrReplace(extractedText, "\\", "\")
                    extractedText := StrReplace(extractedText, '\"', '"')
                    return extractedText
                }
            }
        } else if (provider = "OpenAI") {
            ; 更新的 OpenAI 回應格式: choices[0].message.content
            if InStr(response, '"message":') {
                contentMarker := '"content": "'
                contentStart := InStr(response, contentMarker) + StrLen(contentMarker)
                if (contentStart > StrLen(contentMarker)) {
                    contentEnd := InStr(response, '"', , contentStart)
                    if (contentEnd > contentStart) {
                        extractedText := SubStr(response, contentStart, contentEnd - contentStart)
                        ; 處理轉義字符
                        extractedText := StrReplace(extractedText, "\n", "`n")
                        extractedText := StrReplace(extractedText, "\\", "\")
                        extractedText := StrReplace(extractedText, '\"', '"')
                        return extractedText
                    }
                }
            }
        } else if (provider = "Akash") {
            ; Akash 回應格式 (與 OpenAI 相容，但可能略有不同)
            if InStr(response, '"content":') {
                contentMarker := '"content": "'
                contentStart := InStr(response, contentMarker) + StrLen(contentMarker)
                if (contentStart > StrLen(contentMarker)) {
                    contentEnd := InStr(response, '"', , contentStart)
                    if (contentEnd > contentStart) {
                        extractedText := SubStr(response, contentStart, contentEnd - contentStart)
                        ; 處理轉義字符
                        extractedText := StrReplace(extractedText, "\n", "`n")
                        extractedText := StrReplace(extractedText, "\\", "\")
                        extractedText := StrReplace(extractedText, '\"', '"')
                        return extractedText
                    }
                }
            }
        }
    } catch {
        return "無法提取文字內容。詳細錯誤: " A_LastError
    }
    
    ; 進一步嘗試找出內容
    try {
        if (provider = "OpenAI" || provider = "Akash") {
            ; 嘗試一種更寬鬆的匹配方法
            if InStr(response, '"content":') {
                startPos := InStr(response, '"content":')
                if (startPos > 0) {
                    quotePos := InStr(response, '"', , startPos + 10) + 1
                    if (quotePos > 1) {
                        endQuotePos := InStr(response, '"', , quotePos)
                        if (endQuotePos > quotePos) {
                            return SubStr(response, quotePos, endQuotePos - quotePos)
                        }
                    }
                }
            }
        }
    } catch {
        ; 沒關係，繼續到最後的回傳
    }
    
    return "無法識別回應格式。請檢查原始回應。"
}

; 根據供應商處理並顯示回應
ShowResponse(response, provider := "Claude") {
    ; 創建 GUI
    responseGui := Gui("", provider " 翻譯結果")
    responseGui.SetFont("s10", "微軟正黑體")
    
    ; 提取文字
    extractedText := ExtractResponseText(response, provider)
    
    ; 添加原始文字
    responseGui.AddText("xm w200", "原始文字:")
    originalBox := responseGui.AddEdit("xm w600 h150 ReadOnly")
    originalBox.Value := A_Clipboard
    
    ; 添加翻譯結果
    responseGui.AddText("xm y+10 w200", "翻譯結果:")
    translatedBox := responseGui.AddEdit("xm w600 h150 ReadOnly")
    translatedBox.Value := extractedText
    
    ; 添加複製按鈕
    copyBtn := responseGui.AddButton("xm y+10 w100", "複製翻譯結果")
    copyBtn.OnEvent("Click", (*) => CopyTranslation(extractedText))
    
    ; 添加關閉按鈕
    closeBtn := responseGui.AddButton("x+10 w100", "關閉")
    closeBtn.OnEvent("Click", (*) => responseGui.Destroy())
    
    ; 顯示 GUI
    responseGui.Show("w620 h400")
}

; 複製翻譯結果到剪貼簿
CopyTranslation(text) {
    A_Clipboard := text
    MsgBox("已複製翻譯結果到剪貼簿！", "複製成功", "T1")
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