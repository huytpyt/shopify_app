require "uri"
require "net/http"

class CartController < ApplicationController
  protect_from_forgery with: :null_session
  skip_before_action :verify_authenticity_token

  def discount_cart
    shop_domain =request.env["HTTP_ORIGIN"].to_s.gsub("https://", "")
    shop = Shop.where(shopify_domain: shop_domain).first
    session = ShopifyAPI::Session.new(shop.shopify_domain, shop.shopify_token)
    ShopifyAPI::Base.activate_session(session)
    original_cost = params["original_price"].gsub(".","").to_f
    discount_cost = params["discount_price"].gsub(".","").to_f
    product_array = params["product_array"].map{|id| id.to_i }
    title = "MISKRE_" + [*('a'..'z'),*('0'..'9')].shuffle[0,10].join
    if discount_cost && original_cost > discount_cost
      @new_price_rule = ShopifyAPI::PriceRule.new(
          title: title,
          target_type: "line_item",
          target_selection: "entitled",
          allocation_method: "across",
          value_type: "fixed_amount",
          value: (0 - (original_cost - discount_cost)).to_s,
          usage_limit: 1,
          customer_selection: "all",
          once_per_customer: true,
          prerequisite_subtotal_range: {
              greater_than_or_equal_to: original_cost
          },
          "entitled_product_ids": product_array,
          starts_at: Time.zone.now - 14.days,
          ends_at: Time.zone.now + 2.days
      )
      @new_price_rule.save
      @new_discount_code = ShopifyAPI::DiscountCode.new(
          'price_rule_id': @new_price_rule.id,
          'code': title,
          'usage_count': 1,
          'value_type': 'fixed_amount',
          'value': (0 - (original_cost - discount_cost)).to_s
      )
      @new_discount_code.save

      # cart_items = params[:items_detail]
      # qty = params[:qty]
      # line_items = []
      # cart_items.each_with_index do |item, index |
      #   line_items << { "variant_id": item.to_i, "quantity": qty[index].to_i}
      # end
      # new_checkout = ShopifyAPI::Checkout.new(
      #   "line_items": line_items
      # )
      # binding.pry
      # new_checkout.save
    end
    render json: { result: "OK", discount_code: title}, status: 200
  end


  private

  def cart_param
    params.permit(:original_price, :discount_price, :items_detail, :product_array, :qty)
  end
end