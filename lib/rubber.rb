require 'mechanize'

class Rubber
  def initialize(args)
    @args = args
    @agent = WWW::Mechanize.new
  end
  
  def run
    load_config_file
  end
  
  
  
  protected
  
  def load_config_file
    if File.exists?("config.yml")
      @config = YAML.load(File.read("config.yml"))
    else
      File.open("config.yml", "w") {|f| 
        f.write YAML.dump({:jabber_id => "your@jabber.id", :password => "secret"})
      }
      puts "Brak pliku config.yml. Przykładowy plik został utworzony."
      exit
    end
    
    case @args[0]
    when 'download'
      download
    when 'upload'
      @args.shift
      upload(@args)
    else
      usage
    end
    
  end
  
  def download
    login
    
    @agent.get('https://login.jogger.pl/templates/edit/').links.select{|e| e.href =~ %r[/templates/edit] }.each do |link|
      puts "Pobieranie #{link.href}"
      page = @agent.get(link.href)
      filename = page.body.match(%r[<h3>(.+)</h3>])[1]
      
      filename += ".html" unless filename =~ /\./
      Dir.mkdir("files") unless File.exists?("files")
      
      File.open(File.join("files", filename), 'w') {|f|
        f.write page.forms.first.templatesContent
      }
    end
    
    # ['entries', 'comments', 'login'].each do |file|
    #   @agent.get("https://login.jogger.pl/templates/edit/?file=#{file}")
    # end
  end
  
  def upload(files = [])
    login
    filemap = Hash[*@agent.get('https://login.jogger.pl/templates/edit/').links.select{|e| e.href =~ %r[/templates/edit] }.map {|e| [File.join("files", e.text =~ /\./ ? e.text : e.text + '.html'), e.href]}.flatten]
    
    files.each do |file|
      if url = filemap[file]
        form = @agent.get(url).forms.first
        form.templatesContent = File.read(file)
        form.submit
        puts "Plik #{file} został zaktualizowany"
      else
        puts "Plik #{file} nie istnieje"
      end
    end
  end
  
  def login
    form = @agent.get('https://login.jogger.pl/login/').forms.first
    form.login_jabberid = @config[:jabber_id]
    form.login_jabberpass = @config[:password]
    page = form.submit
    
    if page.uri.to_s == 'https://login.jogger.pl/login/'
      puts "Identyfikator jabbera lub hasło jest nieporawne"
      exit
    end
  end
  
  def usage
    puts <<-USAGE
rubber [action]

Actions:
 download
 upload [file]
USAGE
    exit
  end
  
end