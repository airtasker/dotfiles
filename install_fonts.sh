local terminal iterm2_font_size iterm2_old_font=0 can_install_font=0
local -r font_base_url='https://github.com/romkatv/powerlevel10k-media/raw/master'

function iterm_get() {
  /usr/libexec/PlistBuddy -c "Print :$1" ~/Library/Preferences/com.googlecode.iterm2.plist
}

if [[ "$(uname)" == Darwin && $TERM_PROGRAM == iTerm.app ]]; then
  (( $+commands[curl] )) || return
  [[ $TERM_PROGRAM_VERSION == [2-9]* ]] || return
  if [[ -f ~/Library/Fonts ]]; then
    [[ -d ~/Library/Fonts && -w ~/Library/Fonts ]] || return
  else
    [[ -d ~/Library && -w ~/Library ]] || return
  fi
  [[ -x /usr/libexec/PlistBuddy ]] || return
  [[ -x /usr/bin/plutil ]] || return
  [[ -x /usr/bin/defaults ]] || return
  [[ -f ~/Library/Preferences/com.googlecode.iterm2.plist ]] || return
  [[ -r ~/Library/Preferences/com.googlecode.iterm2.plist ]] || return
  [[ -w ~/Library/Preferences/com.googlecode.iterm2.plist ]] || return
  local guid1 && guid1="$(iterm_get '"Default Bookmark Guid"' 2>/dev/null)" || return
  local guid2 && guid2="$(iterm_get '"New Bookmarks":0:"Guid"' 2>/dev/null)" || return
  local font && font="$(iterm_get '"New Bookmarks":0:"Normal Font"' 2>/dev/null)" || return
  [[ $guid1 == $guid2 ]] || return
  [[ $font != 'MesloLGS-NF-Regular '<-> ]] || return
  # [[ $font == (#b)*' '(<->) ]] || return
  [[ $font == 'MesloLGSNer-Regular '<-> ]] && iterm2_old_font=1
  iterm2_font_size=$match[1]
  terminal=iTerm2
  return 0
fi
return 1


command mkdir -p -- ~/Library/Fonts || exit
local style
for style in Regular Bold Italic 'Bold Italic'; do
local file="MesloLGS NF ${style}.ttf"
echo "Downloading %B$file%b"
curl -fsSL -o ~/Library/Fonts/$file.tmp "$font_base_url/${file// /%20}"
command mv -f -- ~/Library/Fonts/$file{.tmp,} || exit
done
local size=$iterm2_font_size
[[ $size == 12 ]] && size=13
local k t v settings=(
    '"Normal Font"'                                 string '"MesloLGS-NF-Regular '$size'"'
    '"Terminal Type"'                               string '"xterm-256color"'
    '"Horizontal Spacing"'                          real   1
    '"Vertical Spacing"'                            real   1
    '"Minimum Contrast"'                            real   0
    '"Use Bold Font"'                               bool   1
    '"Use Bright Bold"'                             bool   1
    '"Use Italic Font"'                             bool   1
    '"ASCII Anti Aliased"'                          bool   1
    '"Non-ASCII Anti Aliased"'                      bool   1
    '"Use Non-ASCII Font"'                          bool   0
    '"Ambiguous Double Width"'                      bool   0
    '"Draw Powerline Glyphs"'                       bool   1
    '"Only The Default BG Color Uses Transparency"' bool   1
)
for k t v in $settings; do
/usr/libexec/PlistBuddy -c "Set :\"New Bookmarks\":0:$k $v" \
    ~/Library/Preferences/com.googlecode.iterm2.plist 2>/dev/null && continue
    /usr/libexec/PlistBuddy -c \
    "Add :\"New Bookmarks\":0:$k $t $v" ~/Library/Preferences/com.googlecode.iterm2.plist
done
echo "Updating Iterm2 Cache"
# /usr/bin/defaults read com.googlecode.iterm2
sleep 3
print -P ""
() {
local out
out=$(/usr/bin/defaults read 'Apple Global Domain' NSQuitAlwaysKeepsWindows 2>/dev/null) || return
[[ $out == 1 ]] || return
out="$(iterm_get OpenNoWindowsAtStartup 2>/dev/null)" || return
[[ $out == false ]]
}
if (( $? )); then
echo  'Please "restart iTerm2 for the changes to take effect.'
print -P ""
echo '  1. Click" "%BiTerm2 → Quit iTerm2%b or press "%B⌘ Q%b.'
echo '  2. Open iTerm2.'
print -P ""
echo 'It is important to restart iTerm2 by following the instructions above. \
            It is not enough to close iTerm2 by clicking on the red circle. You must \
            click iTerm2 → Quit iTerm2 or press "%B⌘ Q%b.'
fi
