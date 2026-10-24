# Adds the shared-list notification extension (unscrambles notifications on the phone) to the Xcode
# project, and hooks Apple's notification address into Capacitor. Run after add-widget.rb. Safe to run twice.
require 'xcodeproj'

TEAM = '327WHDC3C5'
NOTIFY_ID = 'com.gmoghul.mumbrainsorted.notify'

# --- AppDelegate: pass Apple's notification address (device token) on to the push plugin ---
ad = 'ios/App/App/AppDelegate.swift'
src = File.read(ad)
unless src.include?('capacitorDidRegisterForRemoteNotifications')
  hooks = <<~SWIFT

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationCenter.default.post(name: .capacitorDidRegisterForRemoteNotifications, object: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .capacitorDidFailToRegisterForRemoteNotifications, object: error)
    }
  SWIFT
  i = src.rindex('}') or abort('AppDelegate: closing brace not found')
  src = src[0...i] + hooks.gsub(/^/, '    ').sub(/\A    \n/, "\n") + "}\n"
  File.write(ad, src)
  puts 'AppDelegate: push hooks added'
end

proj = Xcodeproj::Project.open('ios/App/App.xcodeproj')
app = proj.targets.find { |t| t.name == 'App' } or abort('App target not found')
if proj.targets.any? { |t| t.name == 'MumBrainNotify' }
  puts 'Notification extension already added'
  exit 0
end
app_cfg = app.build_configurations.find { |c| c.name == 'Release' } || app.build_configurations.first
version = app_cfg.build_settings['MARKETING_VERSION'] || '1.0'

n = proj.new_target(:app_extension, 'MumBrainNotify', :ios, '15.0', nil, :swift)
ng = proj.main_group.new_group('MumBrainNotify', 'MumBrainNotify')
n.add_file_references([ng.new_reference('NotificationService.swift')])
ng.new_reference('Info.plist')
ng.new_reference('MumBrainNotify.entitlements')

n.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = NOTIFY_ID
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = 'MumBrainNotify/Info.plist'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['CODE_SIGN_ENTITLEMENTS'] = 'MumBrainNotify/MumBrainNotify.entitlements'
  s['DEVELOPMENT_TEAM'] = TEAM
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  s['SKIP_INSTALL'] = 'YES'
  s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  s['MARKETING_VERSION'] = version
  s['CURRENT_PROJECT_VERSION'] = app_cfg.build_settings['CURRENT_PROJECT_VERSION'] || '1'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  s['SWIFT_EMIT_LOC_STRINGS'] = 'NO'
end

# put it inside the app, in the same place as the widget
app.add_dependency(n)
embed = app.copy_files_build_phases.find { |ph| ph.name == 'Embed Foundation Extensions' }
unless embed
  embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  app.build_phases.delete(embed)
  res = app.build_phases.index { |ph| ph.isa == 'PBXResourcesBuildPhase' } || (app.build_phases.length - 1)
  app.build_phases.insert(res + 1, embed)
end
bf = embed.add_file_reference(n.product_reference, true)
bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

proj.save
puts "Notification extension added (version #{version})"
