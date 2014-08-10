module Firebots::InternalAPI::Controllers

  class Account < Kenji::Controller

    # Creates a user. (aka Registration)
    #
    post '/' do

      input = kenji.validated_input do

        validates_type_of 'first_name', 'last_name', 'password',
          is: String

        validates_regex 'email', matches: /^.+@.+\..+$/

        validates 'password', with: -> { self.length >= 8 },
          reason: 'must be at least 8 characters.'

        validates 'email',
          with: -> { Models::Users[email: self].nil? },
          reason: 'must be unique.'

        allow_keys :valid
      end

      password = input.delete('password')
      input[:id] = Rubyflake.generate

      Models::Users.insert(input.merge(
        time_created: Time.now,
        time_updated: Time.now,
        permissions: 'student',
      ))

      user = Models::Users[id: input[:id]]

      Firebots::Password.new(user).save_password!(password)

      {
        status: 200,
        user: sanitized_user(user),
      }
    end

    # Returns information about the currently authenticated user.
    #
    get '/' do
      user = requires_authentication!

      {
        status: 200,
        user: sanitized_user(user),
      }
    end

    # Edits part of a user, eg. change password, email, etc.
    #
    # TODO: real patch keyword
    #
    route :patch, '/' do
      user = requires_authentication!

      input = kenji.validated_input do

        validates_type_of 'first_name', 'last_name', 'password',
          is: String, when: :is_set

        validates_regex 'email', matches: /^.+@.+\..+$/, when: :is_set

        validates 'email',
          with: -> { Models::Users[email: self].nil? || user[:email] == self },
          reason: 'must be unique.', when: :is_set

        validates_type_of 'password', is: String, when: :is_set
        validates 'password', with: -> { self.length >= 8 },
          reason: 'must be at least 8 characters.', when: :is_set

        # ensure old password is present and correct when necessary
        validates 'old_password',
          when: -> { !self['password'].nil? || !self['email'].nil? },
          with: -> { self && Firebots::Password.new(user).verify(self) },
          reason: 'is invalid.'

        allow_keys :valid
      end

      # save new password, if requested
      Firebots::Password.new(user).save_password!(input['password']) if input['password']

      # save other fields to the database
      input.delete('password')
      input.delete('old_password')

      Models::Users.where(id: user[:id]).update(input.merge(
        time_updated: Time.now
      )) unless input.empty?

      new_user = Models::Users[id: user[:id]]

      {
        status: 200,
        user: sanitized_user(new_user),
      }
    end


    # -- Helper methods
    private

    def sanitized_user(user)
      Hash[user.select do |k,_|
        [:id, :first_name, :last_name, :email, :permissions, :time_created, :time_updated].include?(k)
      end.map(&Helpers::HashPairSanitizer)]
    end
  end
end