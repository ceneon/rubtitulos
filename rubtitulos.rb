#!/usr/bin/env ruby
require 'nokogiri'
require 'open-uri'


if ARGV.empty?
  puts "Rubtitulos - Uso: rubtitulos.rb ARCHIVO_AVI" 
  puts "Ejemplo: rubtitulos.rb Great.Series.S01E05....."
  exit
end

# TO-DO: Que en lugar de un nombre de un AVI, tome un directorio (o el actual), y busque el subtítulo por cada .avi que no tenga .srt .

avi = ARGV[0]

v = avi.split(".")
v.each{ |x| x = x.split(" ")}
v.flatten!

# TO-DO: Modificar para que soporte series con varias palabras ... buscar el S0.. o S1..?
serie = v.first
capitulo = v[1]


busqueda = serie + "%20" + capitulo
doc = Nokogiri::HTML(open('http://subdivx.com/index.php?accion=5&masdesc=&subtitulos=1&realiza_b=1&buscar=' + busqueda))

# http://subdivx.com/index.php?buscar=fruta&accion=5&masdesc=&subtitulos=1&realiza_b=1

resultados = Array.new
doc.css("#contenedor_izq div").each{ |div| 

  if div['id'] == "menu_detalle_buscador" then
    titulo = div.content
    
    detalle = div.next.children.css("div").first.content          
        #children.css("#buscador_detalle_sub").first.content #.content.to_s #split("<br>").first
    detalle = detalle.split("<!--").first.gsub("\n", "")
    
    link = div.next.children.css("#buscador_detalle_sub_datos").first.children.css("a")[1]['href']
        
    downloads = div.next.children.css("#buscador_detalle_sub_datos").first.content
    downloads = downloads[11..downloads.index("Cds")-2]
    
    puts titulo.strip + ": " + ( if detalle then detalle else "" end) + " -- " + (if link then link else "" end) + " -- " + (if downloads then downloads + " downloads" else "" end)
    
    # TO-DO: Armar el hash con los datos, y sumarlo a resultados
  end

  # TO-DO: Elegir el más apropiado (o consultar al usuario?)


  # TO-DO: Descargarlo, y descomprimir ZIP/RAR
  
  
  # TO-DO: Eliminar todo lo que no sea .srt 
  
  
  # TO-DO: Renombrar el .srt al mismo nombre del avi   
  # ¿O renombrar avi y srt al nombre "limpio"?


}
