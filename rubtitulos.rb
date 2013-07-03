#!/usr/bin/env ruby
# encoding: utf-8
require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'zipruby'



if ARGV.empty?
  puts "Rubtitulos - Uso: rubtitulos.rb ARCHIVO_AVI" 
  puts "Ejemplo: rubtitulos.rb Great.Series.S01E05....."
  exit
end

class Resultado
  attr_accessor :titulo, :detalle, :link_web_detalle, :downloads
  
  def parsear_subdivx!(div)
    self.titulo = div.content.strip    
    detalle = div.next.children.css("div").first.content          
        #children.css("#buscador_detalle_sub").first.content #.content.to_s #split("<br>").first
        if detalle.split("<!--").first
          self.detalle = detalle.split("<!--").first.gsub("\n", "")
        else
          self.detalle = detalle.gsub("\n", "")
        end
    self.link_web_detalle = div.children.css("div a.titulo_menu_izq")[0]['href']
    #self.link = div.next.children.css("#buscador_detalle_sub_datos").first.children.css("a[target=new]")[0]['href']
    downloads = div.next.children.css("#buscador_detalle_sub_datos").first.content
      self.downloads = downloads[11..downloads.index("Cds")-2].to_i
  end
  
end

# TO-DO: Que en lugar de un nombre de un AVI, tome un directorio (o el actual), y busque el subtítulo por cada .avi que no tenga .srt .

# TO-DO: Convertir en clases "Subtitulo" y "Video" ?  
# srt = Video.new("....avi").subtitulo ?

avi = ARGV[0]

v = avi.split("/").last.split(".")
v.each{ |x| x = x.split(" ")}
v.flatten!

# Parsear nombre de la serie y capítulo
corte = false
pos = 0
serie =""
capitulo =""
while not corte and v[pos] do
  if v[pos].size>2 and (v[pos][0..1] == "S0" or v[pos][0..1] == "S1")
    corte=true
    capitulo = v[pos]
  else
    serie += v[pos] + " "
  end
  pos+=1
end
serie = serie.strip

puts "Buscando serie: " + serie + " - episodio: " + capitulo 
busqueda = serie.gsub(" ", "%20") + "%20" + capitulo


doc = Nokogiri::HTML(open('http://subdivx.com/index.php?accion=5&masdesc=&subtitulos=1&realiza_b=1&buscar=' + busqueda))


resultados = Array.new
doc.css("#contenedor_izq div").each{ |div| 
  if div['id'] == "menu_detalle_buscador" then
    r = Resultado.new
    r.parsear_subdivx!(div)
    resultados << r    
    #puts r.titulo + ": " + ( if r.detalle then r.detalle else "" end) + " -- " + (if r.link then r.link else "" end) + " -- " + (if r.downloads then r.downloads.to_s + " downloads" else "" end)    
  end
}

# Se elige el más popular ...
resultados.sort!{ |x, y| y.downloads <=> x.downloads }

puts "Se encontraron " + resultados.size.to_s + " subtítulos."
if resultados.empty? 
  puts"No se encontraron subtítulos para " + avi
  exit
end
  
puts "Buscando la URL del más popular (" + resultados.first.downloads.to_s + " downloads)..."

doc2 = Nokogiri::HTML(open(resultados.first.link_web_detalle))
link_final = ((doc2.css("#detalle_datos").css("#detalle_datos_derecha")[1]).css(".detalle_link")[1])['href']

puts "Descargando subtítulo..."
tempfile = open(link_final)
srt = Tempfile.new("rubtitulo")

if tempfile.content_type == "application/zip"
  puts "Descomprimiendo ZIP..."
  Zip::Archive.open( tempfile.path )  do |zf|
    # this is a single file archive, so read the first file
    zf.each do |f| 
      # Descarto los archivos que no sean SRT
      if f.name.split(".").last=="srt" then
          puts "SRT: " + f.name
          srt.write f.read
      end
    end
  end
  
elsif tempfile.content_type == "application/x-rar-compressed"

  puts "Descomprimiendo RAR..."
  
  # http://mentalized.net/journal/2010/03/08/5_ways_to_run_commands_from_ruby/
  `mkdir /tmp/rubtitulos >& /dev/null; rm /tmp/rubtitulos/* >& /dev/null`
  #system("unrar l #{tempfile.path}")
  
  # x : extract
  # -n*.srt : filtra por SRT
  # -tsm- : actualiza fecha de modificación a la fecha actual
  # -y : Contesta que sí a toda preegunta
  ## con system(  ) , devuelve true/false
  `cd /tmp/rubtitulos ; unrar x -y -n*.srt -tsm- #{tempfile.path}`
  
  directorio_original = Dir.getwd
  Dir.chdir("/tmp/rubtitulos")
  lista = Dir.glob("*.srt")
  srt.write File.open(lista.first).read
  Dir.chdir(directorio_original)
  #puts lista.to_s
  
  #else
  #  puts "Problemas ejecutando el comando unrar. Está instalado? Descargar versión 'command line only' en: http://www.rarlab.com/download.htm" 
  #  exit
  #end
  
else
  puts "ERROR: Tipo de archivo desconocido"
  exit
end

srt.rewind
if srt.read.empty? then
  puts "ERROR: No se encontró un archivo SRT dentro del ZIP/RAR"
  exit
end

# Renombrar el .srt al mismo nombre del avi   
f = File.new( avi.gsub(".mp4",".avi").gsub(".avi", ".srt").gsub(".mkv", ".srt") , "wb")
srt.rewind
f.write( srt.read )
srt.close
srt.unlink
f.close
  


