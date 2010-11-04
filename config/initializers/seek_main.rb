#DO NOT EDIT THIS FILE.
#TO MODIFY THE DEFAULT SETTINGS, COPY seek_local.rb.pre to seek_local.rb AND EDIT THAT FILE INSTEAD

# this will make the Authorization module available throughout the codebase
require 'authorization'
require 'save_without_timestamping'
require 'asset'

JERM_ENABLED=true unless defined? JERM_ENABLED
SOLR_ENABLED=false unless defined? SOLR_ENABLED
ACTIVITY_LOG_ENABLED=true unless defined? ACTIVITY_LOG_ENABLED
EMAIL_ENABLED=false unless defined? EMAIL_ENABLED
ACTIVATION_REQUIRED=false unless defined? ACTIVATION_REQUIRED
EXCEPTION_NOTIFICATION_ENABLED=false unless defined? EXCEPTION_NOTIFICATION_ENABLED
ENABLE_GOOGLE_ANALYTICS=false unless defined? ENABLE_GOOGLE_ANALYTICS
MERGED_TAG_THRESHOLD=5 unless defined? MERGED_TAG_THRESHOLD
GLOBAL_PASSPHRASE="ohx0ipuk2baiXah" unless defined? GLOBAL_PASSPHRASE
TYPE_MANAGERS="admins" unless defined? TYPE_MANAGERS
HIDE_DETAILS=false unless defined? HIDE_DETAILS

#this is needed for the xlinks in the REST API.
SITE_BASE_HOST="http://localhost:3000" unless defined? SITE_BASE_HOST

# Set Google Analytics code
if ENABLE_GOOGLE_ANALYTICS
  Rubaidh::GoogleAnalytics.tracker_id = GOOGLE_ANALYTICS_TRACKER_ID
else
  Rubaidh::GoogleAnalytics.tracker_id = "000-000"
end

if EXCEPTION_NOTIFICATION_ENABLED
  ExceptionNotifier.render_only = false
else
  ExceptionNotifier.render_only = true
end


#The order in which asset tabs appear
ASSET_ORDER = ['Person', 'Project', 'Institution', 'Investigation', 'Study', 'Assay', 'DataFile', 'Model', 'Sop', 'Publication', 'SavedSearch','Organism']

OpenIdAuthentication.store = :memory
