require 'sequel'
require 'konfiguration'
require 'rubyflake'

if ENV['HOME'] == '/home/ec2-user' || ENV['SUDO_USER'] == 'ec2-user'
  DB = Sequel.connect('postgres://logan:Dj3AsZqAxG3h9x@training.cui9ng4dny4l.us-west-2.rds.amazonaws.com:5432/training')
else
  DB = Sequel.connect(Konfiguration.database(:uri))
end

module Models

  Users = DB[:users]
  Badges = DB[:badges]
  UserBadges = DB[:users_badges]

end
