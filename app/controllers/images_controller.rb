class ImagesController < ApplicationController
  require 'open-uri'
  skip_before_action :verify_authenticity_token

  def proxy
    image_url = params[:url]
    image = URI.open(image_url, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}).read
    send_data image, type: 'image/jpeg', disposition: 'inline'
  rescue OpenURI::HTTPError => e
    render plain: "Image not found", status: :not_found
  end
end