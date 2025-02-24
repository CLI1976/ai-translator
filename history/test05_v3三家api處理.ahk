#Requires AutoHotkey v2.0
#SingleInstance Force

; 快捷鍵設定
F1::SendCurlRequest("Claude")  ; 按F1使用Claude API
F2::SendCurlRequest("OpenAI")  ; 按F2使用OpenAI API
F3::SendCurlRequest("Akash")   ; 按F3使用Akash API

; 發送請求給指定的API供應商
SendCurlRequest(provider := "Claude") {
    ; 檢查curl是否存在
    if !CheckCurlExists() {
        MsgBox("系統中找不到curl命令。請安裝curl或使用其他方法。")
        return
    }
    
    ; 從ini檔讀取API設定
    apiKey := ReadApiKey(provider)
    model := ReadApiModel(provider)
    endpoint := ReadApiEndpoint(provider)
    version := ReadApiVersion(provider)
    
    if !apiKey || !endpoint {
        MsgBox("無法讀取" provider "的API設定。")
        return
    }
    
    ; 根據供應商創建不同的請求內容
    jsonContent := CreateRequestJson(provider, model)
    
    ; 發送請求並獲取回應
    response := SendRequest(provider, endpoint, apiKey, version, jsonContent)
    
    ; 顯示回應
    if response {
        ShowResponse(response, provider)
    }
}

; 從ini檔讀取API設定
ReadApiSetting(provider, key, defaultValue := "") {
    iniFile := A_ScriptDir "\api.ini"
    
    ; 檢查ini檔是否存在
    if !FileExist(iniFile) {
        ; 如果不存在，創建樣板ini檔
        CreateTemplateIniFile(iniFile)
        MsgBox("已創建api.ini樣板檔案。請填入您的API金鑰後再試。")
        return defaultValue
    }
    
    ; 讀取指定供應商的設定
    value := IniRead(iniFile, provider, key, defaultValue)
    return value
}

; 讀取API金鑰
ReadApiKey(provider) {
    apiKey := ReadApiSetting(provider, "ApiKey", "")
    
    ; 檢查API金鑰是否有效
    if (apiKey = "" || InStr(apiKey, "你的") || InStr(apiKey, "your_")) {
        MsgBox("請在api.ini中設定有效的" provider " API金鑰。")
        return ""
    }
    
    return apiKey
}

; 讀取API模型
ReadApiModel(provider) {
    defaultModels := Map(
        "Claude", "claude-3-haiku-20240307",
        "OpenAI", "gpt-4o",
        "Akash", "Meta-Llama-3-1-8B-Instruct-FP8"
    )
    
    model := ReadApiSetting(provider, "Model", defaultModels.Has(provider) ? defaultModels[provider] : "")
    return model
}

; 讀取API端點
ReadApiEndpoint(provider) {
    defaultEndpoints := Map(
        "Claude", "https://api.anthropic.com/v1/messages",
        "OpenAI", "https://api.openai.com/v1/chat/completions",
        "Akash", "https://chatapi.akash.network/api/v1/chat/completions"
    )
    
    endpoint := ReadApiSetting(provider, "Endpoint", defaultEndpoints.Has(provider) ? defaultEndpoints[provider] : "")
    return endpoint
}

; 讀取API版本
ReadApiVersion(provider) {
    defaultVersions := Map(
        "Claude", "2023-06-01",
        "OpenAI", "",
        "Akash", ""
    )
    
    version := ReadApiSetting(provider, "Version", defaultVersions.Has(provider) ? defaultVersions[provider] : "")
    return version
}

; 創建樣板ini檔
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

; 根據供應商創建不同的請求 JSON
CreateRequestJson(provider, model, userMessage := "哈囉，你好？請用繁體中文回答。") {
    ; 準備安全的用戶訊息（寫入檔案再讀取以避免字串問題）
    tempFile := A_Temp "\message_temp.txt"
    FileDelete tempFile
    FileAppend userMessage, tempFile, "UTF-8"
    FileEncoding "UTF-8"
    rawMessage := FileRead(tempFile)
    
    ; 使用硬編碼的 JSON 字串以避免複雜的字串處理
    if (provider = "Claude") {
        return Format('{"model":"{1}","messages":[{"role":"user","content":"哈囉，你好？請用繁體中文回答。"}],"max_tokens":1000}', model)
    } else if (provider = "OpenAI" || provider = "Akash") {
        return Format('{"model":"{1}","messages":[{"role":"user","content":"哈囉，你好？請用繁體中文回答。"}],"max_tokens":1000,"temperature":0.7}', model)
    } else {
        MsgBox("不支援的API供應商: " provider)
        return ""
    }
}


; 發送請求並獲取回應
SendRequest(provider, endpoint, apiKey, version, jsonContent) {
    ; 創建臨時文件
    jsonFile := A_Temp "\" provider "_request.json"
    Try FileDelete(jsonFile)
    
    ; 寫入JSON內容
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
    
    ; 根據供應商準備curl命令
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
    
    ; 執行curl命令
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

; 根據供應商處理並顯示回應
ShowResponse(response, provider := "Claude") {
    ; 創建GUI
    responseGui := Gui("", provider " API 回應")
    responseGui.SetFont("s10", "微軟正黑體")
    
    ; 添加供應商信息
    responseGui.AddText("w200", "供應商: " provider)
    
    ; 添加顯示區域
    responseGui.AddText("xm y+10 w100", "回應內容:")
    responseBox := responseGui.AddEdit("xm w600 h300 ReadOnly")
    responseBox.Value := response
    
    ; 根據不同供應商提取文字
    extractedText := ExtractResponseText(response, provider)
    
    if extractedText {
        ; 在另一個框中顯示提取的文字
        responseGui.AddText("xm y+10 w100", "提取的文字:")
        extractedBox := responseGui.AddEdit("xm w600 h150 ReadOnly")
        extractedBox.Value := extractedText
    }
    
    ; 添加關閉按鈕
    closeBtn := responseGui.AddButton("xm w100", "關閉")
    closeBtn.OnEvent("Click", (*) => responseGui.Destroy())
    
    ; 顯示GUI
    responseGui.Show("w620 h550")
}