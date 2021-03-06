module ShopifyAPI
  module Limits
    class Error < StandardError
    end
  end
end


module ActiveResource
  class Base
    SHOPIFY_MAX_RECORDS_PER_REQUEST = 250

    def self.find_all(params = {}, &block)
      records = 0
      params[:limit] ||= 50
      params[:page] = 1

      begin
        page = find(:all, :params => params)
        return records if page.nil?
        page.each do |value|
          records += 1
          block.call(value)
        end
        params[:page] += 1
      end until page.length < params[:limit]
      records
    end

    class << self
      # get reference to unbound class-method #find_every
      find_every = self.instance_method(:find_every)

      define_method(:find_every) do |options|
        options[:params] ||= {}

        # Determine number of ShopifyAPI requests to stitch together all records of this query.
        limit = options[:params][:limit]


        results = []
        results.singleton_class.class_eval do
          attr_accessor :requests_made
        end
        results.requests_made = 0

        # Bail out to default functionality unless limit == false
        # NOTE: the algorithm was switched from doing a count and pre-calculating pages
        # because Shopify 404s on some count requests
        if limit == false
          options[:params].update(:limit => SHOPIFY_MAX_RECORDS_PER_REQUEST)

          limit = SHOPIFY_MAX_RECORDS_PER_REQUEST
          last_count = 0 - limit
          page = 0
          # as long as the number of results we got back is not less than the limit we (probably) have more to fetch
          while( (results.count - last_count) >= limit) do
            page +=1
            last_count = results.count
            options[:params][:page] = page
            next_result = find_every.bind(self).call(options)
            results.concat next_result unless next_result.nil?
            results.requests_made += 1
          end
        else
          next_result = find_every.bind(self).call(options)
          results.concat next_result unless next_result.nil?
          results.requests_made += 1
        end

        results
      end
    end
  end
end