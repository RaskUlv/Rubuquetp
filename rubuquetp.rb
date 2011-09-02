#!/usr/share/env ruby
# coding: utf-8

require 'fileutils'
require 'optparse'

options = {}

optparse = OptionParser.new do |opts|
	opts.banner = "Usage: rubuquetp.rb [options]"
	opts.on('-b', '--book FILE', "Path to your book") do |book|
		options[:book] = book
	end
	opts.on('-e', '--engine OCRENGINE', "Engine to use") do |engine|
		options[:engine] = engine
	end
	opts.on('-l', '--lang LANG', "Language") do |lang|
		options[:lang] = lang
	end
	opts.on('-h', '--help', "Display this help") do
		puts opts
		exit
	end
end

optparse.parse!

path = options[:book]
engine = options[:engine]
lang = options[:lang]

class Book
	
	attr_accessor :path, :engine, :lang

	def initialize(path, engine, lang)
		@path = path
		@engine = engine
		@lang = lang
		@ext = File.extname(@path)
		@filename = File.basename(@path, ".*")
		@tempdir = "/tmp/#{@filename}"
		@filedir = File.dirname(@path)
	end
	
	def pdfile
		if @ext == '.pdf'
			pdfile = @path
		elsif @ext == '.djvu'
			pdfile = "#{@tempdir}/#{@filename}.pdf"
		else
			puts "File type #{@ext} not supported"
			exit
		end
		return pdfile
	end

	def pages
		exc = ["pdfinfo", "#{pdfile}"]
		f = IO.popen(exc).grep(/Pages:\s\d*/)
		fstring = f[0]
		pagenmb = (/\d*$/).match(fstring)
		pags = pagenmb[0].to_i
		return pags		
	end
	
	def runocr
		FileUtils.mkdir(@tempdir) unless Dir.exists?(@tempdir)
		if @engine == 'cf'
			gsdev = 'pngmono'
			gsformat = 'png'
		elsif @engine == 'tr'
			gsdev = 'tiffg4'
			gsformat = 'tif'
		else
			puts "Engine not set"
			exit
		end
		system("ddjvu", "-format=pdf", "-mode=black", "-quality=100", "#{@path}", "#{@tempdir}/#{@filename}.pdf") if @ext == '.djvu'
		system("gs", "-r150", "-q", "-sDEVICE=#{gsdev}", "-dDOINTERPOLATE", "-dNOPAUSE", "-dTextAlphaBits=4", "-dGraphicsAlphaBits=4", "-sOutputFile=#{@tempdir}/image-%04d.#{gsformat}", "--", "#{pdfile}")
		print "Starting OCR process. Pages left: #{pages}"
		
		pages.times do |page|
			fmtpage = format("%.4d", "#{page+1}")
			if @engine == 'cf'
				commnd = "cuneiform '#{@tempdir}/image-#{fmtpage}.png' -l #{@lang} -o '#{@tempdir}/text-#{fmtpage}.txt' >> /dev/null 2>> /dev/null"
			elsif @engine == 'tr'
				commnd = "tesseract '#{@tempdir}/image-#{fmtpage}.tif' '#{@tempdir}/text-#{fmtpage}' -l #{@lang} >> /dev/null 2>> /dev/null"
			else
				puts "Engine is not set"
				exit
			end
			system(commnd)
			i =pages-page
			n = (pages.to_s).length
			ifmt = format("%#{n}d", i)
 			print "\b"*n+"#{ifmt}"
		end

  	outfile = File.new("#{@filedir}/#{@filename}.txt", "a+")
  	srcents = Dir.entries( "#{@tempdir}" )
  	srcfls = srcents.grep(/.txt/).sort
  	
		srcfls.each do |filetx|
  		tempst = File.read("#{@tempdir}/#{filetx}")
  		File.open("#{@filedir}/#{@filename}.txt", "a+") do |file|
				file.write tempst
			end	
		end
	
  	puts "\nOCR is done: #{@filename}"
  	FileUtils.rm_rf(@tempdir)
	end

end

book = Book.new(path,engine,lang)
book.runocr
