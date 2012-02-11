#!/usr/bin/env ruby
# encoding: utf-8
require 'nokogiri'
require 'open-uri'
require 'zipruby'



if ARGV.empty?
  puts "Rubtitulos - Uso: rubtitulos.rb ARCHIVO_AVI" 
  puts "Ejemplo: rubtitulos.rb Great.Series.S01E05....."
  exit
end

class Resultado
  attr_accessor :titulo, :detalle, :link, :downloads
  
  def parsear_subdivx!(div)
    self.titulo = div.content.strip    
    detalle = div.next.children.css("div").first.content          
        #children.css("#buscador_detalle_sub").first.content #.content.to_s #split("<br>").first
        if detalle.split("<!--").first
          self.detalle = detalle.split("<!--").first.gsub("\n", "")
        else
          self.detalle = detalle.gsub("\n", "")
        end
    self.link = div.next.children.css("#buscador_detalle_sub_datos").first.children.css("a[target=new]")[0]['href']
    downloads = div.next.children.css("#buscador_detalle_sub_datos").first.content
      self.downloads = downloads[11..downloads.index("Cds")-2].to_i
  end
  
end

# TO-DO: Que en lugar de un nombre de un AVI, tome un directorio (o el actual), y busque el subtítulo por cada .avi que no tenga .srt .

# TO-DO: Convertir en clases "Subtitulo" y "Video" ?  
# srt = Video.new("....avi").subtitulo ?

avi = ARGV[0]

v = avi.split(".")
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
serie = serie.strip.gsub(" ", "%20")

busqueda = serie + "%20" + capitulo
puts "Buscando serie: " + serie + " - episodio: " + capitulo 

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
  
puts "Descargando el más popular (" + resultados.first.downloads.to_s + " downloads)..."

puts resultados.first.link


tempfile = open(resultados.first.link)
srt = Tempfile.new("rubtitulo")

if tempfile.content_type == "application/zip"
  
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
  puts "es un RAR... y ahora?"
  exit
  # TO-DO: Unrar solo de el/los SRT
  
  
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
f = File.new( avi.gsub(".avi", ".srt") , "wb")
srt.rewind
f.write( srt.read )
srt.close
srt.unlink
f.close
  


