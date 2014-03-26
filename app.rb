require "rubygems"
require "nokogiri"
require "sinatra"
require "open-uri"
require "net/https"

BASE_MKM_URL = "https://www.magickartenmarkt.de"
api_url = ""
forward_to = ""

enable :sessions

get "/" do
  @title = "Main"
	@msg = ""
	
	erb :index
end

get "/down/:file" do |file|
  send_file("./down/#{file}", :filename => file, :type => "application/octet-stream", :disposition => "attachment")
end

get "/login" do
  @title = "Login"
  erb :login
end

post "/login" do
	require "mechanize"
	
  agent = Mechanize.new
  agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  
  page = agent.get("#{BASE_MKM_URL}")
  login_form = page.forms[1]

  unless login_form.nil?
    login_form["username"] = params[:user]
    login_form["userPassword"] = params[:pass]
    login_form.submit
  end

  page = agent.get("#{BASE_MKM_URL}/?mainPage=showMyAccount")
  api_key = page.parser.css(".myAccountPersonalData-table a")[1].text unless page.parser.css(".myAccountPersonalData-table a")[1].nil?

  unless api_key.nil?
    api_url = "https://www.mkmapi.eu/ws/#{params[:user]}/#{api_key}"
  else
    redirect to "/login"
  end

  if forward_to.length > 0
    redirect to forward_to
  else
    redirect to "/"
  end
end


get "/search" do
  @title = "Suche"
	
  erb :search
end

get "/result" do
  redirect to "/search"
end

post "/result" do
  card = params[:searchStr]
  @title = "Ergebnis für '#{card}'"

  card = card.gsub(" ", "%20")
  @resList = []
  
  xml = Nokogiri::XML(open("https://www.mkmapi.eu/ws/stevinyl/c4076bff0dc81ba0d93d858081a0c513/products/#{card}/1/1/false", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))

  xml.css("product").each do |product|
    prodHash = {}
    
    unless product.at_css("idProduct").nil?
      prodHash["idProduct"] = product.at_css("idProduct").text
      prodHash["productName"] = product.at_css("name productName").text
      prodHash["priceGuide"] = "Low: #{product.at_css("priceGuide LOW").text}€  /  Avg: #{product.at_css("priceGuide AVG").text}€"
      prodHash["expansion"] = product.at_css("expansion").text
      prodHash["rarity"] = product.at_css("rarity").text unless product.at_css("rarity").nil?
      prodHash["image"] = product.at_css("image").text[1..-1]
    end

    @resList.push(prodHash)
  end

  erb :result
end
=begin
get "/card/:cardId" do
  @title = "Karte"
  erb :card, :layout => false
end
=end
before "/wants" do
  if api_url.length == 0
    forward_to = "/wants"
    redirect to "/login"
  end
end

get "/wants" do
  @title = "Wants"
  @wantsList = []
  
  xml = Nokogiri::XML(open("#{api_url}/wantslist", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
  
  xml.css("wantsList").each do |want|
    wantHash = {}
    
    wantHash["idWantsList"] = want.at_css("idWantsList").text
    wantHash["name"] = want.css("name")[1].text
    wantHash["itemCount"] = want.at_css("itemCount").text
    
    @wantsList.push(wantHash)
  end
  
  erb :wants
end

before "/want/:wantId" do
  if api_url.length == 0
    forward_to = "/want/#{params[:wantId]}"
    redirect to "/login"
  end
end

get "/want/:wantId" do
  @title = "Wants-Karten"
  @wantList = []
  
  xml = Nokogiri::XML(open("#{api_url}/wantslist/#{params[:wantId]}", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
  
  xml.css("want").each do |want|
    wantHash = {}
    
    wantHash["idWant"] = want.at_css("idWant").text
    wantHash["idMetaproduct"] = want.at_css("idMetaproduct").text
    wantHash["type"] = want.at_css("type").text
    wantHash["amount"] = want.at_css("amount").text
    
    mcard_xml = Nokogiri::XML(open("#{api_url}/metaproduct/#{wantHash["idMetaproduct"]}", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
    wantHash["productName"] = mcard_xml.at_css("name metaproductName").text
    
    @wantList.push(wantHash)
  end
  
  @wantList.sort_by! {|k| k["productName"]}
  
  erb :want
end

before "/want/:metaId/detail" do
  if api_url.length == 0
    redirect to "/login"
  end
end

get "/want/:metaId/detail" do
  mcard_xml = Nokogiri::XML(open("#{api_url}/metaproduct/#{params[:metaId]}", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
  
  @title = "Details von #{mcard_xml.at_css("metaproduct metaproductName").text}"
  @resList = []
    
  productHash = {}

  mcard_xml.css("products idProduct").each do |product|
    productHash = {}
    
    card_xml = Nokogiri::XML(open("#{api_url}/product/#{product.text}", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
    productHash["idProduct"] = card_xml.at_css("idProduct").text
    productHash["productName"] = card_xml.at_css("name productName").text
    productHash["priceGuide"] = "Low:#{card_xml.at_css("priceGuide LOW").text}€  /  Avg:#{card_xml.at_css("priceGuide AVG").text}€"
    productHash["expansion"] = card_xml.at_css("expansion").text
    productHash["rarity"] = card_xml.at_css("rarity").text unless card_xml.at_css("rarity").nil?
    productHash["image"] = card_xml.at_css("image").text[1..-1]
    
    @resList.push(productHash)
  end
  
  erb :result
end

before "/orders/:actor" do
  if api_url.length == 0
    forward_to = "/orders/#{params[:actor]}"
    redirect to "/login"
  end
end

get "/orders/:actor" do
  actor = params[:actor]
  @title = actor == "1" ? "Verkäufe" : "Einkäufe"
  
  @boughtList = []
  bought_xml = Nokogiri::XML(open("#{api_url}/orders/#{actor}/1", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
  bought_xml.css("order").each do |order|
    unless order.at_css("seller").nil?
      hash = {}
      
      hash["shippingMethod_name"] = order.at_css("shippingMethod name").text
      hash["shippingMethod_price"] = order.at_css("shippingMethod price").text
      hash["shippingAddress_name"] = order.at_css("shippingAddress name").text
      hash["shippingAddress_extra"] = order.at_css("shippingAddress extra").text
      hash["shippingAddress_street"] = order.at_css("shippingAddress street").text
      hash["shippingAddress_city"] = order.at_css("shippingAddress zip").text + " " + order.at_css("shippingAddress city").text
      hash["shippingAddress_country"] = order.at_css("shippingAddress country").text
      hash["articleValue"] = order.at_css("articleValue").text
      hash["totalValue"] = order.at_css("totalValue").text

      hash["articles"] = []
      order.css("article").each do |article|
        card = {}
        card["idProduct"] = article.at_css("idProduct").text

        card_xml = Nokogiri::XML(open("#{api_url}/product/#{card["idProduct"]}", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
        card["productName"] = card_xml.at_css("name productName").text
        card["priceGuide"] = "Low:#{card_xml.at_css("priceGuide LOW").text}€  /  Avg:#{card_xml.at_css("priceGuide AVG").text}€"
        card["image"] = card_xml.at_css("image").text[1..-1]

        card["price"] = article.at_css("price").text
        card["count"] = article.at_css("count").text
        hash["articles"].push(card)
      end

      hash["articles"].sort_by! {|k| k["productName"]}
      
      @boughtList.push(hash)
    end
  end
  
  @paidList = []
  paid_xml = Nokogiri::XML(open("#{api_url}/orders/#{actor}/2", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
  paid_xml.css("order").each do |order|
    unless order.at_css("seller").nil?
      hash = {}
      
      hash["shippingMethod_name"] = order.at_css("shippingMethod name").text
      hash["shippingMethod_price"] = order.at_css("shippingMethod price").text
      hash["shippingAddress_name"] = order.at_css("shippingAddress name").text
      hash["shippingAddress_extra"] = order.at_css("shippingAddress extra").text
      hash["shippingAddress_street"] = order.at_css("shippingAddress street").text
      hash["shippingAddress_city"] = order.at_css("shippingAddress zip").text + " " + order.at_css("shippingAddress city").text
      hash["shippingAddress_country"] = order.at_css("shippingAddress country").text
      hash["articleValue"] = order.at_css("articleValue").text
      hash["totalValue"] = order.at_css("totalValue").text

      hash["articles"] = []
      order.css("article").each do |article|
        card = {}
        card["idProduct"] = article.at_css("idProduct").text

        card_xml = Nokogiri::XML(open("#{api_url}/product/#{card["idProduct"]}", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
        card["productName"] = card_xml.at_css("name productName").text
        card["priceGuide"] = "Low:#{card_xml.at_css("priceGuide LOW").text}€  /  Avg:#{card_xml.at_css("priceGuide AVG").text}€"
        card["image"] = card_xml.at_css("image").text[1..-1]

        card["price"] = article.at_css("price").text
        card["count"] = article.at_css("count").text
        hash["articles"].push(card)
      end

      hash["articles"].sort_by! {|k| k["productName"]}
      
      @paidList.push(hash)
    end
  end
  
  
  @sentList = []
  sent_xml = Nokogiri::XML(open("#{api_url}/orders/#{actor}/4", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
  sent_xml.css("order").each do |order|
    unless order.at_css("seller").nil?
      hash = {}
      
      hash["shippingMethod_name"] = order.at_css("shippingMethod name").text
      hash["shippingMethod_price"] = order.at_css("shippingMethod price").text
      hash["shippingAddress_name"] = order.at_css("shippingAddress name").text
      hash["shippingAddress_extra"] = order.at_css("shippingAddress extra").text
      hash["shippingAddress_street"] = order.at_css("shippingAddress street").text
      hash["shippingAddress_city"] = order.at_css("shippingAddress zip").text + " " + order.at_css("shippingAddress city").text
      hash["shippingAddress_country"] = order.at_css("shippingAddress country").text
      hash["articleValue"] = order.at_css("articleValue").text
      hash["totalValue"] = order.at_css("totalValue").text

      hash["articles"] = []
      order.css("article").each do |article|
        card = {}
        card["idProduct"] = article.at_css("idProduct").text

        card_xml = Nokogiri::XML(open("#{api_url}/product/#{card["idProduct"]}", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
        card["productName"] = card_xml.at_css("name productName").text
        card["priceGuide"] = "Low:#{card_xml.at_css("priceGuide LOW").text}€  /  Avg:#{card_xml.at_css("priceGuide AVG").text}€"
        card["image"] = card_xml.at_css("image").text[1..-1]

        card["price"] = article.at_css("price").text
        card["count"] = article.at_css("count").text
        hash["articles"].push(card)
      end

      hash["articles"].sort_by! {|k| k["productName"]}
            
      @sentList.push(hash)
    end
  end
  
  erb :orders
end

