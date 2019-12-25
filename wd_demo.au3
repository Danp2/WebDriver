#include "wd_core.au3"
#include "wd_helper.au3"
#include <FileConstants.au3>

Local Enum $eFireFox = 0, _
			$eChrome, _
			$eEdge

Local $aDemoSuite[][2] = [["DemoTimeouts", False], _
						["DemoNavigation", True], _
						["DemoElements", False], _
						["DemoScript", False], _
						["DemoCookies", False], _
						["DemoAlerts", False], _
						["DemoFrames", False], _
						["DemoActions", False], _
						["DemoWindows", False]]

Local Const $_TestType = $eChrome
Local Const $sElementSelector = "//input[@name='q']"

Local $sDesiredCapabilities
Local $iIndex
Local $sSession

$_WD_DEBUG = $_WD_DEBUG_Info

Switch $_TestType
	Case $eFireFox
		SetupGecko()

	Case $eChrome
		SetupChrome()

	Case $eEdge
		SetupEdge()

EndSwitch

_WD_Startup()

If @error <> $_WD_ERROR_Success Then
	Exit -1
EndIf

$sSession = _WD_CreateSession($sDesiredCapabilities)

If @error = $_WD_ERROR_Success Then
	For $iIndex = 0 To UBound($aDemoSuite, $UBOUND_ROWS) - 1
		If $aDemoSuite[$iIndex][1] Then
			ConsoleWrite("Running: " & $aDemoSuite[$iIndex][0] & @CRLF)
			Call($aDemoSuite[$iIndex][0])
		Else
			ConsoleWrite("Bypass: " & $aDemoSuite[$iIndex][0] & @CRLF)
		EndIf
	Next
EndIf

_WD_DeleteSession($sSession)
_WD_Shutdown()


Func DemoTimeouts()
	; Retrieve current settings and save
	Local $sResponse = _WD_Timeouts($sSession)
	Local $oJSON = Json_Decode($sResponse)
	Local $sTimouts = Json_Encode(Json_Get($oJSON, "[value]"))

	_WD_Navigate($sSession, "http://google.com")

	; Set page load timeout
	_WD_Timeouts($sSession, '{"pageLoad":2000}')

	; Retrieve current settings
	_WD_Timeouts($sSession)

	; This should timeout
	_WD_Navigate($sSession, "http://yahoo.com")

	; Restore initial settings
	_WD_Timeouts($sSession, $sTimouts)
EndFunc

Func DemoNavigation()
	_WD_Navigate($sSession, "http://google.com")
	_WD_NewTab($sSession)
	_WD_Navigate($sSession, "http://yahoo.com")
	_WD_NewTab($sSession, True, -1, 'http://bing.com', 'width=200,height=200')

	ConsoleWrite("URL=" & _WD_Action($sSession, 'url') & @CRLF)
	_WD_Attach($sSession, "google.com", "URL")
	ConsoleWrite("URL=" & _WD_Action($sSession, 'url') & @CRLF)
	_WD_Attach($sSession, "yahoo.com", "URL")
	ConsoleWrite("URL=" & _WD_Action($sSession, 'url') & @CRLF)
EndFunc

Func DemoElements()
	Local $sElement, $aElements, $sValue

	_WD_Navigate($sSession, "http://google.com")

	; Locate a single element
	$sElement = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $sElementSelector)

	; Locate multiple matching elements
	$aElements = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, "//div/input", '', True)
	_ArrayDisplay($aElements, "Found Elements")

	; Set element's contents
	_WD_ElementAction($sSession, $sElement, 'value', "testing 123")
	Sleep(500)

	; Retrieve then clear contents
	$sValue = _WD_ElementAction($sSession, $sElement, 'property', 'value')
	_WD_ElementAction($sSession, $sElement, 'clear')
	Sleep(500)

	_WD_ElementAction($sSession, $sElement, 'value', "abc xyz")
	Sleep(500)

	$sValue = _WD_ElementAction($sSession, $sElement, 'property', 'value')
	_WD_ElementAction($sSession, $sElement, 'clear')
	Sleep(500)

	_WD_ElementAction($sSession, $sElement, 'value', "fujimo")
	Sleep(500)
	$sValue = _WD_ElementAction($sSession, $sElement, 'property', 'value')

	; Click input element
	_WD_ElementAction($sSession, $sElement, 'click')

	; Click search button
    $sButton = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, "//input[@name='btnK']")
    _WD_ElementAction($sSession, $sButton, 'click')
    _WD_LoadWait($sSession, 2000)

	$sElement = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $sElementSelector)
	$sValue = _WD_ElementAction($sSession, $sElement, 'property', 'value')
	ConsoleWrite('value = ' & $sValue & @CRLF)

	; Take element screenshot
	$sResponse = _WD_ElementAction($sSession, $sElement, 'screenshot')
	$bDecode = _Base64Decode($sResponse)
	$sDecode = BinaryToString($bDecode)

	$hFileOpen = FileOpen("Element.png", $FO_BINARY + $FO_OVERWRITE)
	FileWrite($hFileOpen, $sDecode)
	FileClose($hFileOpen)
EndFunc

Func DemoScript()
	_WD_ExecuteScript($sSession, "return arguments[0].second;", '{"first": "1st", "second": "2nd", "third": "3rd"}')
	_WD_Alert($sSession, 'Dismiss')
EndFunc

Func DemoCookies()
	_WD_Navigate($sSession, "http://google.com")
	_WD_Cookies($sSession, 'Get', 'NID')

	Local $sName = "Testname"
	Local $sValue ="TestValue"
	Local $sCookie = '{"cookie": {"name":"' & $sName & '","value":"' & $sValue & '"}}'
	_WD_Cookies($sSession, 'add', $sCookie)
	_WD_Cookies($sSession, 'Get', $sName)
EndFunc

Func DemoAlerts()
	ConsoleWrite('Alert Detected => ' & _WD_Alert($sSession, 'status') & @CRLF)
	_WD_ExecuteScript($sSession, "alert('testing 123')")
	ConsoleWrite('Alert Detected => ' & _WD_Alert($sSession, 'status') & @CRLF)
	ConsoleWrite('Text Detected => ' & _WD_Alert($sSession, 'gettext') & @CRLF)
	_WD_Alert($sSession, 'sendtext', 'new text')
	ConsoleWrite('Text Detected => ' & _WD_Alert($sSession, 'gettext') & @CRLF)
	Sleep(5000)
	_WD_Alert($sSession, 'Dismiss')

EndFunc

Func DemoFrames()
	_WD_Navigate($sSession, "https://www.w3schools.com/tags/tryit.asp?filename=tryhtml_frame_cols")
	ConsoleWrite("Frames=" & _WD_GetFrameCount($sSession) & @CRLF)
	ConsoleWrite("TopWindow=" & _WD_IsWindowTop($sSession) & @CRLF)
	$sElement = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, "//iframe[@id='iframeResult']")
	_WD_FrameEnter($sSession, $sElement)
	ConsoleWrite("TopWindow=" & _WD_IsWindowTop($sSession) & @CRLF)
	_WD_FrameLeave($sSession)
	ConsoleWrite("TopWindow=" & _WD_IsWindowTop($sSession) & @CRLF)

EndFunc

Func DemoActions()
	Local $sElement, $aElements, $sValue

	_WD_Navigate($sSession, "http://google.com")
	$sElement = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $sElementSelector)

ConsoleWrite("$sElement = " & $sElement & @CRLF)

	$sAction = '{"actions":[{"id":"default mouse","type":"pointer","parameters":{"pointerType":"mouse"},"actions":[{"duration":100,"x":0,"y":0,"type":"pointerMove","origin":{"ELEMENT":"'
	$sAction &= $sElement & '","' & $_WD_ELEMENT_ID & '":"' & $sElement & '"}},{"button":2,"type":"pointerDown"},{"button":2,"type":"pointerUp"}]}]}'

ConsoleWrite("$sAction = " & $sAction & @CRLF)

	_WD_Action($sSession, "actions", $sAction)
	sleep(5000)
	_WD_Action($sSession, "actions")
	sleep(5000)
EndFunc

Func DemoWindows()
	Local $sResponse, $hFileOpen, $sHnd1, $sHnd2

	$sHnd1 = '{"handle":"' & _WD_Window($sSession, "window") & '"}'
	_WD_Navigate($sSession, "http://google.com")

	_WD_NewTab($sSession)
	$sHnd2 = '{"handle":"' & _WD_Window($sSession, "window") & '"}'
	_WD_Navigate($sSession, "http://yahoo.com")

	_WD_Window($sSession, "switch", $sHnd1)
	$sResponse = _WD_Window($sSession, 'screenshot')
	$bDecode = _Base64Decode($sResponse)
	$sDecode = BinaryToString($bDecode)

	$hFileOpen = FileOpen("Screen1.png", $FO_BINARY + $FO_OVERWRITE)
	FileWrite($hFileOpen, $sDecode)
	FileClose($hFileOpen)

	_WD_Window($sSession, "switch", $sHnd2)
	$sResponse = _WD_Window($sSession, 'screenshot')
	$bDecode = _Base64Decode($sResponse)
	$sDecode = BinaryToString($bDecode)

	$hFileOpen = FileOpen("Screen2.png", $FO_BINARY + $FO_OVERWRITE)
	FileWrite($hFileOpen, $sDecode)
	FileClose($hFileOpen)
EndFunc

Func SetupGecko()
_WD_Option('Driver', 'geckodriver.exe')
_WD_Option('DriverParams', '--log trace')
_WD_Option('Port', 4444)

$sDesiredCapabilities = '{"desiredCapabilities":{"javascriptEnabled":true,"nativeEvents":true,"acceptInsecureCerts":true}}'
EndFunc

Func SetupChrome()
_WD_Option('Driver', 'chromedriver.exe')
_WD_Option('Port', 9515)
_WD_Option('DriverParams', '--log-path="' & @ScriptDir & '\chrome.log"')

$sDesiredCapabilities = '{"capabilities": {"alwaysMatch": {"goog:chromeOptions": {"w3c": true }}}}'
EndFunc

Func SetupEdge()
_WD_Option('Driver', 'MicrosoftWebDriver.exe')
_WD_Option('Port', 17556)
_WD_Option('DriverParams', '--verbose')

$sDesiredCapabilities = '{"capabilities":{}}'
EndFunc

