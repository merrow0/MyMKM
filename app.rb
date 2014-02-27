require "rubygems"
require "nokogiri"
require "sinatra"
require "open-uri"
require "net/https"

BASE_MKM_URL = "https://www.magickartenmarkt.de/"
API_URL = "https://www.mkmapi.eu/ws/stevinyl/c4076bff0dc81ba0d93d858081a0c513"

get "/" do
  @title = "Main"
	erb :index
end

get "/search" do
  @title = "Suche"
  erb :search
end

post "/search" do
  @card = params[:searchStr]
  @title = "Suchergebnis fuer #{@card}"

	erb :result
end

get "/wants" do
  @title = "Wants"
  @wantsList = []
  
  xml = Nokogiri::XML(open("#{API_URL}/wantslist", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
  
  xml.css("wantsList").each do |want|
    wantHash = {}
    
    wantHash["idWantsList"] = want.at_css("idWantsList").text
    wantHash["name"] = want.css("name")[1].text
    wantHash["itemCount"] = want.at_css("itemCount").text
    
    @wantsList.push(wantHash)
  end
  
  erb :wants
end

get "/want/:wantId" do
  @title = "Karten von "
  @wantList = []
  
  xml = Nokogiri::XML(open("#{API_URL}/wantslist/#{params[:wantId]}", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
  
  xml.css("want").each do |want|
    wantHash = {}
    
    wantHash["idWant"] = want.at_css("idWant").text
    wantHash["idMetaproduct"] = want.at_css("idMetaproduct").text
    wantHash["type"] = want.at_css("type").text
    wantHash["amount"] = want.at_css("amount").text
    
    card_xml = Nokogiri::XML(open("#{API_URL}/metaproduct/#{wantHash["idMetaproduct"]}", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
    wantHash["metaproductName"] = card_xml.at_css("metaproduct metaproductName").text
    wantHash["idProduct"] = card_xml.at_css("metaproduct idProduct").text
    
    @wantList.push(wantHash)
  end
  
  erb :want
end
