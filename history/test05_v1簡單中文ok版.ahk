#Requires AutoHotkey v2.0
#SingleInstance Force

; 按F1發送請求給Claude API
F1::SendCurlRequest()

; 使用curl發送請求，避免BOM問題
SendCurlRequest() {
    ; 你的API金鑰 - 替換成你的實際金鑰
    apiKey := "sk-yourkey" ; 替換成你真實的 API 金鑰
    
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
    responseGui.SetFont("s10", "微軟正黑體")
    
    ; 添加顯示區域
    responseGui.AddText("w100", "回應內容:")
    responseBox := responseGui.AddEdit("xm w600 h400 ReadOnly")
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
                responseGui.AddText("xm y+20 w100", "提取的文字:")
                extractedBox := responseGui.AddEdit("xm y+5 w600 h100 ReadOnly")
                extractedBox.Value := extractedText
            }
        }
    }
    
    ; 添加關閉按鈕
    closeBtn := responseGui.AddButton("xm w100", "關閉")
    closeBtn.OnEvent("Click", (*) => responseGui.Destroy())
    
    ; 顯示GUI
    responseGui.Show("w620 h550")
}