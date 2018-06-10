#
# Progressive Web Application 'Add to Home Screen' support
#
class Install < Vue
  def render
    _button.btn.btn_primary 'install', onClick: self.click
  end

  def click(event)
    PageCache.installprompt.prompt();
    PageCache.installprompt.userChoice.then do |result|
      console.log "install: #{result}"
      PageCache.installprompt = nil
      Main.refresh()
    end
  end
end