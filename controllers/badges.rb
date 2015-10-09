# coding: utf-8

require 'aws-sdk'
require 'fortune_gem'
require 'lib/email'
require 'lib/cache'

require 'controllers/badges/userbadges'

module Firebots
  module InternalAPI::Controllers

    class Badges < Kenji::Controller

      pass '/user', ::Firebots::InternalAPI::Controllers::UserBadges

      # Returns a specified badge.
      #
      get '/:id' do |id|
        badge = Models::Badges[id: id.to_i]
        kenji.respond(404, 'No such badge.') unless badge

        {
          status: 200,
          badge: sanitized_badge(badge),
        }
      end

      # Creates a new badge
      #
      post '/' do
        user = requires_authentication!
        unless user[:permissions] == 'mentor' || user[:permissions] == 'lead'
          kenji.respond(403, "You don't have badge creation permissions.")
        end

        input = kenji.validated_input do
          validates_type_of 'name', 'description', 'category', 'subcategory',
            'learning_method', 'resources', is: String
          validates_type_of 'assessment', 'verifiers', is: String, when: :is_set
          validates_type_of 'year', is: Integer, when: :is_set
        end

        input[:id] = Rubyflake.generate

        Models::Badges.insert(input.merge(
          time_created: Time.now,
          time_updated: Time.now,
        ))

        badge = Models::Badges[id: input[:id]]

        Models::Users.each do |user|
          Models::UserBadges.insert({
            user_id: user[:id],
            badge_id: badge[:id],
            status: 'no',
            id: Rubyflake.generate,
            time_created: Time.now,
            time_updated: Time.now,
          })
        end

        send_new_badge_email(badge, user)

        {
          status: 200,
          badge: sanitized_badge(badge)
        }
      end

      # Returns a list of all badges
      #
      get '/all' do
        unless badges = Cache.get('all-badges')
          Cache.set('all-badges',
                    result = Models::Badges.where(is_deleted: false)
                                           .order(:year,
                                                  :category,
                                                  :subcategory).all,
                    20)
        end

        badges ||= result

        {
          status: 200,
          all:    badges.map { |b| sanitized_badge(b) }
        }
      end

      # Updates badge properties.
      #
      patch '/:id' do |id|
        user = requires_authentication!
        unless user[:permissions] == 'mentor' || user[:permissions] == 'lead'
          kenji.respond(403, "You don't have badge update permissions.")
        end

        input = kenji.validated_input do
          validates_type_of 'name', 'description', 'category', 'subcategory',
            'learning_method', 'assessment', 'resources', 'verifiers',
            is: String, when: :is_set
          validates_type_of 'year', is: Integer, when: :is_set
        end

        badge = Models::Badges[id: id.to_i]
        kenji.respond(404, 'No such badge.') unless badge

        Models::Badges.where(id: badge[:id]).update(input.merge(
          time_updated: Time.now,
        ))

        {
          status: 200,
          message: 'Badge info changed.',
        }
      end

      get '/s3-creds' do
        user = requires_authentication!
        unless user[:permissions] == 'mentor' || user[:permissions] == 'lead'
          kenji.respond(403, "You don't have permissions to get S3 creds.")
        end

        s3 = AWS::S3.new
        bucket = s3.buckets['3501-training-2014-us-west-2']
        post = AWS::S3::PresignedPost.new(bucket)

        post.fields
      end

      get '/categories' do
        {
          status: 200,
          categories: get_categories.sort,
        }
      end

      post '/:id' do |id|
        user = requires_authentication!
        unless user[:permissions] == 'mentor' || user[:permissions] == 'lead'
          kenji.respond(403, 'You are not allowed to delete badges.')
        end

        Models::Badges.where(id: id).update(is_deleted:   true,
                                            time_updated: Time.now)

        {
          status: 200,
          message: 'Badge deleted.'
        }
      end

      # -- Helper methods
      private

      def get_categories
        cached = Cache.get('categories')
        return cached if cached

        categories = Models::Badges.where(is_deleted: false)
                                   .select_map(:category)
        categories = Set.new(categories).to_a

        Cache.set('categories', categories, 30)
        categories
      end

      def sanitized_badge(badge)
        Hash[badge.select do |k,_|
          [:id, :time_created, :time_updated, :name, :description,
            :learning_method, :assessment, :category, :subcategory, :year,
            :resources, :verifiers].include?(k)
        end.map(&Helpers::HashPairSanitizer)]
      end

      def send_new_badge_email(badge, user)
        Firebots::Email.send(
          from: 'admin@mg.fremontrobotics.com',
          to: 'Sohini Stone <sohiniss@gmail.com>',
          cc: ['Logan Howard <logan@oflogan.com>'],
          subject: 'New badge – 3501',
          text: <<-EOM
            Hi Sohini,

            #{user[:first_name]} (#{user[:title]}) has created a new #{badge[:category]} badge.
            Link: https://app.fremontrobotics.com/badge/#{badge[:id]}

            Name: #{badge[:name]}
            Subcategory: #{badge[:subcategory]}

            Description:
            #{badge[:description]}

            -----

            #{::FortuneGem.give_fortune}
          EOM
        )
      end
    end
  end
end
