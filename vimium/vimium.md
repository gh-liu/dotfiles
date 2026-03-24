## key mappings

```vim
map g? showHelp
map gs toggleViewSource

"=== Navigating the page
"===
map j scrollDown
map k scrollUp
map h scrollLeft
map l scrollRight

map gg scrollToTop
map G  scrollToBottom
map 0  scrollToLeft
map $  scrollToRight

"map <c-u> scrollPageUp      
"map <c-d> scrollPageDown    
"map <c-f> scrollFullPageUp
"map <c-b> scrollFullPageDown

"map r reload
"map R reload

map Uy copyCurrentUrl
map Up openCopiedUrlInCurrentTab
map UP openCopiedUrlInNewTab

map f  LinkHints.activateMode                    
map F  LinkHints.activateModeToOpenInNewTab      
map yf LinkHints.activateModeToCopyLinkUrl

map m Marks.activateCreateMode
map M Marks.activateGotoMode

map : Vomnibar.activate                         
map o Vomnibar.activate                         
map O Vomnibar.activateInNewTab                 
map b Vomnibar.activateBookmarks                
map B Vomnibar.activateBookmarksInNewTab        
"map t Vomnibar.activateTabSelection             
"map T Vomnibar.activateTabSelection             
map Ue Vomnibar.activateEditUrl
map UE Vomnibar.activateEditUrlInNewTab

"=== Using find
"===
map / enterFindMode                             
map ? enterFindMode                             
map n performFind                               
map N performBackwardsFind                      
map * findSelected
map # findSelectedBackwards

"=== Navigating history
"===
"map H goBack
"map L goForward

"=== Manipulating tabs
"===
"map t createTab
"map yt duplicateTab
map [ previousTab
map ] nextTab
map { moveTabLeft
map } moveTabRight
```

## search engines

```text
b: https://www.baidu.com/s?wd=%s BaiDu
g: https://www.google.com/search?q=%s Google
w: https://www.wikipedia.org/w/index.php?title=Special:Search&search=%s Wikipedia
```
