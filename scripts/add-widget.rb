# Adds the home screen widget (and the app's widget bridge) to the Xcode project that
# Capacitor creates on GitHub's Mac. Safe to run more than once.
require 'xcodeproj'

TEAM = '327WHDC3C5'
WIDGET_ID = 'com.gmoghul.mumbrainsorted.widget'

proj = Xcodeproj::Project.open('ios/App/App.xcodeproj')
app = proj.targets.find { |t| t.name == 'App' } or abort('App target not found')
if proj.targets.any? { |t| t.name == 'MumBrainWidget' }
  puts 'Widget already added'
  exit 0
end

# --- the app: bridge plugin, main screen and App Group ---
app_group = proj.main_group.children.find { |g| g.respond_to?(:path) && g.path == 'App' } or abort('App group not found')
%w[WidgetBridgePlugin.swift MainViewController.swift].each do |f|
  app.add_file_references([app_group.new_reference(f)])
end
app_group.new_reference('App.entitlements')
app.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'App/App.entitlements'
end
app_cfg = app.build_configurations.find { |c| c.name == 'Release' } || app.build_configurations.first
version = app_cfg.build_settings['MARKETING_VERSION'] || '1.0'

# --- the widget extension ---
w = proj.new_target(:app_extension, 'MumBrainWidget', :ios, '15.0', nil, :swift)
wg = proj.main_group.new_group('MumBrainWidget', 'MumBrainWidget')
w.add_file_references([wg.new_reference('MumBrainWidget.swift')])
wg.new_reference('Info.plist')
wg.new_reference('MumBrainWidget.entitlements')
fonts = Dir['ios/App/MumBrainWidget/Fonts/*.ttf'].sort.map { |p| wg.new_reference("Fonts/#{File.basename(p)}") }
w.add_resources(fonts)
pngs = Dir['ios/App/MumBrainWidget/*.png'].sort.map { |p| wg.new_reference(File.basename(p)) }
w.add_resources(pngs)

w.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = WIDGET_ID
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = 'MumBrainWidget/Info.plist'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['CODE_SIGN_ENTITLEMENTS'] = 'MumBrainWidget/MumBrainWidget.entitlements'
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

# --- put the widget inside the app ---
app.add_dependency(w)
embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
bf = embed.add_file_reference(w.product_reference, true)
bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
# keep it straight after Resources, before any script phases (avoids Xcode's "cycle" error)
app.build_phases.delete(embed)
res = app.build_phases.index { |ph| ph.isa == 'PBXResourcesBuildPhase' } || (app.build_phases.length - 1)
app.build_phases.insert(res + 1, embed)

proj.save
puts "Widget added (version #{version})"
