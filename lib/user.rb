require 'lib/password'
require 'lib/email'

module Firebots
  module User
    # the input args should look like:
    # {first_name: 'lala', last_name: 'po',
    # technical_group: 'dipsy', email: 'tinky@winky.co}
    #
    def self.create(args)
      email = args['email'].downcase

      fail "Email already exists: #{email}" if Models::Users[email: email]

      id       = Rubyflake.generate
      username = args['first_name'].downcase
      username = id.to_s if Models::Users[username: username]
      password = Password.pronounceable
      now      = Time.now

      args = args.merge('password' => password,
                        'username' => username,
                        'id'       => id)

      send_invite_email(args)

      Models::Users.insert(args.merge('time_created' => now,
                                      'time_updated' => now,
                                      'permissions'  => 'student'))

      user = Models::Users[id: id]

      Firebots::Password.new(user).save_password!(password)

      Models::Badges.each do |badge|
        Models::UserBadges.insert(user_id:      user[:id],
                                  badge_id:     badge[:id],
                                  status:       'no',
                                  id:           Rubyflake.generate,
                                  time_created: now,
                                  time_updated: now)
      end

      user
    end

    def self.send_invite_email(args)
      Firebots::Email.send(
        from: 'admin@mg.fremontrobotics.com',
        to: args[:email],
        subject: '3501 FRC Training',
        text: <<-EOM
          Hello #{args[:first_name]},

          You've been added to the FRC 3501 training site: https://app.fremontrobotics.com/about.

          Your temporary password is `#{args[:password]}`. You should change it immediately.

          To get a proper avatar, sign up with your email at https://gravatar.com.

          Reply to this email to get help with anything.
        EOM
      )
    end
  end
end
