import os
import uuid

def generate_uuid():
    return uuid.uuid4().hex[:24].upper()

def create_project():
    proj_dir = "Vachanam.xcodeproj"
    os.makedirs(proj_dir, exist_ok=True)
    
    # Collect all source files
    vachanam_files = []
    for root, dirs, files in os.walk("Vachanam"):
        if "Packages" in dirs:
            dirs.remove("Packages")
        for f in files:
            if f.endswith(".swift"):
                full_path = os.path.join(root, f)
                vachanam_files.append((f, full_path))
    
    test_files = []
    for root, _, files in os.walk("VachanamTests"):
        for f in files:
            if f.endswith(".swift"):
                full_path = os.path.join(root, f)
                test_files.append((f, full_path))
                
    uitest_files = []
    for root, _, files in os.walk("VachanamUITests"):
        for f in files:
            if f.endswith(".swift"):
                full_path = os.path.join(root, f)
                uitest_files.append((f, full_path))

    file_refs = {}
    build_files = {}
    
    for fname, fpath in vachanam_files + test_files + uitest_files:
        f_uuid = generate_uuid()
        b_uuid = generate_uuid()
        file_refs[fpath] = (f_uuid, fname)
        build_files[fpath] = (b_uuid, f_uuid)
    
    plist_uuid = generate_uuid()
    registry_uuid = generate_uuid()
    registry_b_uuid = generate_uuid()
    
    assets_uuid = generate_uuid()
    assets_b_uuid = generate_uuid()
    
    font_reg_uuid = generate_uuid()
    font_reg_b_uuid = generate_uuid()
    
    font_bold_uuid = generate_uuid()
    font_bold_b_uuid = generate_uuid()
    
    kokoro_models_uuid = generate_uuid()
    kokoro_models_b_uuid = generate_uuid()
    
    spm_pkg_ref_uuid = generate_uuid()
    spm_kokorotts_dep_uuid = generate_uuid()
    spm_kokorotts_build_file_uuid = generate_uuid()
    spm_kokorotts_test_build_file_uuid = generate_uuid()
    
    proj_uuid = generate_uuid()
    main_group_uuid = generate_uuid()
    app_group_uuid = generate_uuid()
    tests_group_uuid = generate_uuid()
    uitests_group_uuid = generate_uuid()
    products_group_uuid = generate_uuid()
    
    app_target_uuid = generate_uuid()
    tests_target_uuid = generate_uuid()
    uitests_target_uuid = generate_uuid()
    
    app_proxy_uuid = generate_uuid()
    app_dep_uuid = generate_uuid()
    
    uitest_proxy_uuid = generate_uuid()
    uitest_dep_uuid = generate_uuid()
    
    app_sources_phase = generate_uuid()
    app_resources_phase = generate_uuid()
    app_frameworks_phase = generate_uuid()
    
    tests_sources_phase = generate_uuid()
    tests_frameworks_phase = generate_uuid()
    
    uitests_sources_phase = generate_uuid()
    uitests_frameworks_phase = generate_uuid()
    
    app_product_uuid = generate_uuid()
    tests_product_uuid = generate_uuid()
    uitests_product_uuid = generate_uuid()
    
    config_list_proj = generate_uuid()
    config_list_app = generate_uuid()
    config_list_tests = generate_uuid()
    config_list_uitests = generate_uuid()
    
    conf_debug_proj = generate_uuid()
    conf_release_proj = generate_uuid()
    conf_debug_app = generate_uuid()
    conf_release_app = generate_uuid()
    conf_debug_tests = generate_uuid()
    conf_release_tests = generate_uuid()
    conf_debug_uitests = generate_uuid()
    conf_release_uitests = generate_uuid()

    pbx = [
        "// !$*UTF8*$!",
        "{",
        "\tarchiveVersion = 1;",
        "\tclasses = {",
        "\t};",
        "\tobjectVersion = 56;",
        "\tobjects = {",
        "",
        "/* Begin PBXBuildFile section */"
    ]
    
    for fpath in vachanam_files:
        b_uuid, f_uuid = build_files[fpath[1]]
        fname = fpath[0]
        pbx.append(f"\t\t{b_uuid} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {f_uuid} /* {fname} */; }};")
        
    for fpath in test_files:
        b_uuid, f_uuid = build_files[fpath[1]]
        fname = fpath[0]
        pbx.append(f"\t\t{b_uuid} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {f_uuid} /* {fname} */; }};")
        
    for fpath in uitest_files:
        b_uuid, f_uuid = build_files[fpath[1]]
        fname = fpath[0]
        pbx.append(f"\t\t{b_uuid} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {f_uuid} /* {fname} */; }};")
        
    pbx.append(f"\t\t{registry_b_uuid} /* model_registry.json in Resources */ = {{isa = PBXBuildFile; fileRef = {registry_uuid} /* model_registry.json */; }};")
    pbx.append(f"\t\t{font_reg_b_uuid} /* OpenDyslexic-Regular.otf in Resources */ = {{isa = PBXBuildFile; fileRef = {font_reg_uuid} /* OpenDyslexic-Regular.otf */; }};")
    pbx.append(f"\t\t{font_bold_b_uuid} /* OpenDyslexic-Bold.otf in Resources */ = {{isa = PBXBuildFile; fileRef = {font_bold_uuid} /* OpenDyslexic-Bold.otf */; }};")
    pbx.append(f"\t\t{assets_b_uuid} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_uuid} /* Assets.xcassets */; }};")
    pbx.append(f"\t\t{kokoro_models_b_uuid} /* KokoroModels in Resources */ = {{isa = PBXBuildFile; fileRef = {kokoro_models_uuid} /* KokoroModels */; }};")
    pbx.append("/* End PBXBuildFile section */")
    pbx.append("")
    
    pbx.append("/* Begin PBXContainerItemProxy section */")
    pbx.append(f"\t\t{app_proxy_uuid} /* PBXContainerItemProxy */ = {{")
    pbx.append("\t\t\tisa = PBXContainerItemProxy;")
    pbx.append(f"\t\t\tcontainerPortal = {proj_uuid} /* Project object */;")
    pbx.append("\t\t\tproxyType = 1;")
    pbx.append(f"\t\t\tremoteGlobalIDString = {app_target_uuid};")
    pbx.append("\t\t\tremoteInfo = Vachanam;")
    pbx.append("\t\t};")
    
    pbx.append(f"\t\t{uitest_proxy_uuid} /* PBXContainerItemProxy */ = {{")
    pbx.append("\t\t\tisa = PBXContainerItemProxy;")
    pbx.append(f"\t\t\tcontainerPortal = {proj_uuid} /* Project object */;")
    pbx.append("\t\t\tproxyType = 1;")
    pbx.append(f"\t\t\tremoteGlobalIDString = {app_target_uuid};")
    pbx.append("\t\t\tremoteInfo = Vachanam;")
    pbx.append("\t\t};")
    pbx.append("/* End PBXContainerItemProxy section */")
    pbx.append("")
    
    # XCLocalSwiftPackageReference section
    pbx.append("/* Begin XCLocalSwiftPackageReference section */")
    pbx.append(f"\t\t{spm_pkg_ref_uuid} /* XCLocalSwiftPackageReference \"swift-tts\" */ = {{")
    pbx.append("\t\t\tisa = XCLocalSwiftPackageReference;")
    pbx.append('\t\t\trelativePath = "Vachanam/Packages/kokoro-coreml/swift-tts";')
    pbx.append("\t\t};")
    pbx.append("/* End XCLocalSwiftPackageReference section */")
    pbx.append("")
    
    # XCSwiftPackageProductDependency section
    pbx.append("/* Begin XCSwiftPackageProductDependency section */")
    pbx.append(f"\t\t{spm_kokorotts_dep_uuid} /* KokoroTTS */ = {{")
    pbx.append("\t\t\tisa = XCSwiftPackageProductDependency;")
    pbx.append(f"\t\t\tpackage = {spm_pkg_ref_uuid} /* XCLocalSwiftPackageReference \"swift-tts\" */;")
    pbx.append("\t\t\tproductName = KokoroTTS;")
    pbx.append("\t\t};")
    pbx.append("/* End XCSwiftPackageProductDependency section */")
    pbx.append("")
    
    pbx.append("/* Begin PBXFileReference section */")
    pbx.append(f"\t\t{app_product_uuid} /* Vachanam.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Vachanam.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    pbx.append(f"\t\t{tests_product_uuid} /* VachanamTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = VachanamTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    pbx.append(f"\t\t{uitests_product_uuid} /* VachanamUITests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = VachanamUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    
    for fpath, (f_uuid, fname) in file_refs.items():
        pbx.append(f"\t\t{f_uuid} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{fpath}\"; sourceTree = \"<group>\"; }};")
        
    pbx.append(f"\t\t{plist_uuid} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = \"Vachanam/Info.plist\"; sourceTree = \"<group>\"; }};")
    pbx.append(f"\t\t{registry_uuid} /* model_registry.json */ = {{isa = PBXFileReference; lastKnownFileType = text.json; path = \"Vachanam/Resources/model_registry.json\"; sourceTree = \"<group>\"; }};")
    pbx.append(f"\t\t{font_reg_uuid} /* OpenDyslexic-Regular.otf */ = {{isa = PBXFileReference; lastKnownFileType = file; path = \"Vachanam/Resources/OpenDyslexic-Regular.otf\"; sourceTree = \"<group>\"; }};")
    pbx.append(f"\t\t{font_bold_uuid} /* OpenDyslexic-Bold.otf */ = {{isa = PBXFileReference; lastKnownFileType = file; path = \"Vachanam/Resources/OpenDyslexic-Bold.otf\"; sourceTree = \"<group>\"; }};")
    pbx.append(f"\t\t{assets_uuid} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = \"Vachanam/Resources/Assets.xcassets\"; sourceTree = \"<group>\"; }};")
    pbx.append(f"\t\t{kokoro_models_uuid} /* KokoroModels */ = {{isa = PBXFileReference; lastKnownFileType = folder; path = \"Vachanam/Resources/KokoroModels\"; sourceTree = \"<group>\"; }};")
    pbx.append("/* End PBXFileReference section */")
    pbx.append("")
    
    pbx.append("/* Begin PBXFrameworksBuildPhase section */")
    pbx.append(f"\t\t{app_frameworks_phase} /* Frameworks */ = {{")
    pbx.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    pbx.append("\t\t\tbuildActionMask = 2147483647;")
    pbx.append("\t\t\tfiles = (")
    pbx.append(f"\t\t\t\t{spm_kokorotts_build_file_uuid} /* KokoroTTS in Frameworks */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    pbx.append("\t\t};")
    
    pbx.append(f"\t\t{tests_frameworks_phase} /* Frameworks */ = {{")
    pbx.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    pbx.append("\t\t\tbuildActionMask = 2147483647;")
    pbx.append("\t\t\tfiles = (")
    pbx.append(f"\t\t\t\t{spm_kokorotts_test_build_file_uuid} /* KokoroTTS in Frameworks */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    pbx.append("\t\t};")
    
    pbx.append(f"\t\t{uitests_frameworks_phase} /* Frameworks */ = {{")
    pbx.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    pbx.append("\t\t\tbuildActionMask = 2147483647;")
    pbx.append("\t\t\tfiles = (")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    pbx.append("\t\t};")
    pbx.append("/* End PBXFrameworksBuildPhase section */")
    pbx.append("")
    
    pbx.append("/* Begin PBXGroup section */")
    pbx.append(f"\t\t{main_group_uuid} = {{")
    pbx.append("\t\t\tisa = PBXGroup;")
    pbx.append("\t\t\tchildren = (")
    pbx.append(f"\t\t\t\t{app_group_uuid} /* Vachanam */,")
    pbx.append(f"\t\t\t\t{tests_group_uuid} /* VachanamTests */,")
    pbx.append(f"\t\t\t\t{uitests_group_uuid} /* VachanamUITests */,")
    pbx.append(f"\t\t\t\t{products_group_uuid} /* Products */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tsourceTree = \"<group>\";")
    pbx.append("\t\t};")
    
    # App Group
    pbx.append(f"\t\t{app_group_uuid} /* Vachanam */ = {{")
    pbx.append("\t\t\tisa = PBXGroup;")
    pbx.append("\t\t\tchildren = (")
    for _, fpath in vachanam_files:
        f_uuid, fname = file_refs[fpath]
        pbx.append(f"\t\t\t\t{f_uuid} /* {fname} */,")
    pbx.append(f"\t\t\t\t{plist_uuid} /* Info.plist */,")
    pbx.append(f"\t\t\t\t{registry_uuid} /* model_registry.json */,")
    pbx.append(f"\t\t\t\t{font_reg_uuid} /* OpenDyslexic-Regular.otf */,")
    pbx.append(f"\t\t\t\t{font_bold_uuid} /* OpenDyslexic-Bold.otf */,")
    pbx.append(f"\t\t\t\t{assets_uuid} /* Assets.xcassets */,")
    pbx.append(f"\t\t\t\t{kokoro_models_uuid} /* KokoroModels */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tpath = \".\";")
    pbx.append("\t\t\tsourceTree = \"<group>\";")
    pbx.append("\t\t};")
    
    # Tests Group
    pbx.append(f"\t\t{tests_group_uuid} /* VachanamTests */ = {{")
    pbx.append("\t\t\tisa = PBXGroup;")
    pbx.append("\t\t\tchildren = (")
    for _, fpath in test_files:
        f_uuid, fname = file_refs[fpath]
        pbx.append(f"\t\t\t\t{f_uuid} /* {fname} */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tpath = \".\";")
    pbx.append("\t\t\tsourceTree = \"<group>\";")
    pbx.append("\t\t};")
    
    # UITests Group
    pbx.append(f"\t\t{uitests_group_uuid} /* VachanamUITests */ = {{")
    pbx.append("\t\t\tisa = PBXGroup;")
    pbx.append("\t\t\tchildren = (")
    for _, fpath in uitest_files:
        f_uuid, fname = file_refs[fpath]
        pbx.append(f"\t\t\t\t{f_uuid} /* {fname} */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tpath = \".\";")
    pbx.append("\t\t\tsourceTree = \"<group>\";")
    pbx.append("\t\t};")
    
    # Products Group
    pbx.append(f"\t\t{products_group_uuid} /* Products */ = {{")
    pbx.append("\t\t\tisa = PBXGroup;")
    pbx.append("\t\t\tchildren = (")
    pbx.append(f"\t\t\t\t{app_product_uuid} /* Vachanam.app */,")
    pbx.append(f"\t\t\t\t{tests_product_uuid} /* VachanamTests.xctest */,")
    pbx.append(f"\t\t\t\t{uitests_product_uuid} /* VachanamUITests.xctest */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tname = Products;")
    pbx.append("\t\t\tsourceTree = \"<group>\";")
    pbx.append("\t\t};")
    pbx.append("/* End PBXGroup section */")
    pbx.append("")
    
    # Target Dependencies
    pbx.append("/* Begin PBXTargetDependency section */")
    pbx.append(f"\t\t{app_dep_uuid} /* PBXTargetDependency */ = {{")
    pbx.append("\t\t\tisa = PBXTargetDependency;")
    pbx.append(f"\t\t\ttarget = {app_target_uuid} /* Vachanam */;")
    pbx.append(f"\t\t\ttargetProxy = {app_proxy_uuid} /* PBXContainerItemProxy */;")
    pbx.append("\t\t};")
    
    pbx.append(f"\t\t{uitest_dep_uuid} /* PBXTargetDependency */ = {{")
    pbx.append("\t\t\tisa = PBXTargetDependency;")
    pbx.append(f"\t\t\ttarget = {app_target_uuid} /* Vachanam */;")
    pbx.append(f"\t\t\ttargetProxy = {uitest_proxy_uuid} /* PBXContainerItemProxy */;")
    pbx.append("\t\t};")
    pbx.append("/* End PBXTargetDependency section */")
    pbx.append("")
    
    # Native Targets
    pbx.append("/* Begin PBXNativeTarget section */")
    pbx.append(f"\t\t{app_target_uuid} /* Vachanam */ = {{")
    pbx.append("\t\t\tisa = PBXNativeTarget;")
    pbx.append(f"\t\t\tbuildConfigurationList = {config_list_app} /* Build configuration list for PBXNativeTarget \"Vachanam\" */;")
    pbx.append("\t\t\tbuildPhases = (")
    pbx.append(f"\t\t\t\t{app_sources_phase} /* Sources */,")
    pbx.append(f"\t\t\t\t{app_frameworks_phase} /* Frameworks */,")
    pbx.append(f"\t\t\t\t{app_resources_phase} /* Resources */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tbuildRules = (")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tdependencies = (")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tname = Vachanam;")
    pbx.append(f"\t\t\tpackageProductDependencies = (")
    pbx.append(f"\t\t\t\t{spm_kokorotts_dep_uuid} /* KokoroTTS */,")
    pbx.append("\t\t\t);")
    pbx.append(f"\t\t\tproductName = Vachanam;")
    pbx.append(f"\t\t\tproductReference = {app_product_uuid} /* Vachanam.app */;")
    pbx.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    pbx.append("\t\t};")
    
    pbx.append(f"\t\t{tests_target_uuid} /* VachanamTests */ = {{")
    pbx.append("\t\t\tisa = PBXNativeTarget;")
    pbx.append(f"\t\t\tbuildConfigurationList = {config_list_tests} /* Build configuration list for PBXNativeTarget \"VachanamTests\" */;")
    pbx.append("\t\t\tbuildPhases = (")
    pbx.append(f"\t\t\t\t{tests_sources_phase} /* Sources */,")
    pbx.append(f"\t\t\t\t{tests_frameworks_phase} /* Frameworks */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tbuildRules = (")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tdependencies = (")
    pbx.append(f"\t\t\t\t{app_dep_uuid} /* PBXTargetDependency */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tname = VachanamTests;")
    pbx.append(f"\t\t\tpackageProductDependencies = (")
    pbx.append(f"\t\t\t\t{spm_kokorotts_dep_uuid} /* KokoroTTS */,")
    pbx.append("\t\t\t);")
    pbx.append(f"\t\t\tproductName = VachanamTests;")
    pbx.append(f"\t\t\tproductReference = {tests_product_uuid} /* VachanamTests.xctest */;")
    pbx.append("\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
    pbx.append("\t\t};")
    
    pbx.append(f"\t\t{uitests_target_uuid} /* VachanamUITests */ = {{")
    pbx.append("\t\t\tisa = PBXNativeTarget;")
    pbx.append(f"\t\t\tbuildConfigurationList = {config_list_uitests} /* Build configuration list for PBXNativeTarget \"VachanamUITests\" */;")
    pbx.append("\t\t\tbuildPhases = (")
    pbx.append(f"\t\t\t\t{uitests_sources_phase} /* Sources */,")
    pbx.append(f"\t\t\t\t{uitests_frameworks_phase} /* Frameworks */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tbuildRules = (")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tdependencies = (")
    pbx.append(f"\t\t\t\t{uitest_dep_uuid} /* PBXTargetDependency */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tname = VachanamUITests;")
    pbx.append(f"\t\t\tproductName = VachanamUITests;")
    pbx.append(f"\t\t\tproductReference = {uitests_product_uuid} /* VachanamUITests.xctest */;")
    pbx.append("\t\t\tproductType = \"com.apple.product-type.bundle.ui-testing\";")
    pbx.append("\t\t};")
    pbx.append("/* End PBXNativeTarget section */")
    pbx.append("")
    
    # Project section
    pbx.append("/* Begin PBXProject section */")
    pbx.append(f"\t\t{proj_uuid} /* Project object */ = {{")
    pbx.append("\t\t\tisa = PBXProject;")
    pbx.append("\t\t\tattributes = {")
    pbx.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    pbx.append("\t\t\t\tLastUpgradeCheck = 1600;")
    pbx.append("\t\t\t\tLastSwiftUpdateCheck = 1600;")
    pbx.append("\t\t\t\tTargetAttributes = {")
    pbx.append(f"\t\t\t\t\t{app_target_uuid} = {{")
    pbx.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    pbx.append("\t\t\t\t\t};")
    pbx.append(f"\t\t\t\t\t{tests_target_uuid} = {{")
    pbx.append(f"\t\t\t\t\t\tTestTargetID = {app_target_uuid};")
    pbx.append("\t\t\t\t\t};")
    pbx.append(f"\t\t\t\t\t{uitests_target_uuid} = {{")
    pbx.append(f"\t\t\t\t\t\tTestTargetID = {app_target_uuid};")
    pbx.append("\t\t\t\t\t};")
    pbx.append("\t\t\t\t};")
    pbx.append("\t\t\t};")
    pbx.append(f"\t\t\tbuildConfigurationList = {config_list_proj} /* Build configuration list for PBXProject \"Vachanam\" */;")
    pbx.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    pbx.append("\t\t\tdevelopmentRegion = en;")
    pbx.append("\t\t\thasScannedForEncodings = 0;")
    pbx.append("\t\t\tknownRegions = (")
    pbx.append("\t\t\t\ten,")
    pbx.append("\t\t\t\tBase,")
    pbx.append("\t\t\t);")
    pbx.append(f"\t\t\tmainGroup = {main_group_uuid};")
    pbx.append(f"\t\t\tpackageReferences = (")
    pbx.append(f"\t\t\t\t{spm_pkg_ref_uuid} /* XCLocalSwiftPackageReference \"swift-tts\" */,")
    pbx.append(f"\t\t\t);")
    pbx.append(f"\t\t\tproductRefGroup = {products_group_uuid} /* Products */;")
    pbx.append("\t\t\tprojectDirPath = \"\";")
    pbx.append("\t\t\tprojectRoot = \"\";")
    pbx.append("\t\t\ttargets = (")
    pbx.append(f"\t\t\t\t{app_target_uuid} /* Vachanam */,")
    pbx.append(f"\t\t\t\t{tests_target_uuid} /* VachanamTests */,")
    pbx.append(f"\t\t\t\t{uitests_target_uuid} /* VachanamUITests */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t};")
    pbx.append("/* End PBXProject section */")
    pbx.append("")
    
    # Resources Phase
    pbx.append("/* Begin PBXResourcesBuildPhase section */")
    pbx.append(f"\t\t{app_resources_phase} /* Resources */ = {{")
    pbx.append("\t\t\tisa = PBXResourcesBuildPhase;")
    pbx.append("\t\t\tbuildActionMask = 2147483647;")
    pbx.append("\t\t\tfiles = (")
    pbx.append(f"\t\t\t\t{registry_b_uuid} /* model_registry.json in Resources */,")
    pbx.append(f"\t\t\t\t{font_reg_b_uuid} /* OpenDyslexic-Regular.otf in Resources */,")
    pbx.append(f"\t\t\t\t{font_bold_b_uuid} /* OpenDyslexic-Bold.otf in Resources */,")
    pbx.append(f"\t\t\t\t{assets_b_uuid} /* Assets.xcassets in Resources */,")
    pbx.append(f"\t\t\t\t{kokoro_models_b_uuid} /* KokoroModels in Resources */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    pbx.append("\t\t};")
    pbx.append("/* End PBXResourcesBuildPhase section */")
    pbx.append("")
    
    # Sources Phase
    pbx.append("/* Begin PBXSourcesBuildPhase section */")
    pbx.append(f"\t\t{app_sources_phase} /* Sources */ = {{")
    pbx.append("\t\t\tisa = PBXSourcesBuildPhase;")
    pbx.append("\t\t\tbuildActionMask = 2147483647;")
    pbx.append("\t\t\tfiles = (")
    for _, fpath in vachanam_files:
        b_uuid, _ = build_files[fpath]
        fname = os.path.basename(fpath)
        pbx.append(f"\t\t\t\t{b_uuid} /* {fname} in Sources */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    pbx.append("\t\t};")
    
    pbx.append(f"\t\t{tests_sources_phase} /* Sources */ = {{")
    pbx.append("\t\t\tisa = PBXSourcesBuildPhase;")
    pbx.append("\t\t\tbuildActionMask = 2147483647;")
    pbx.append("\t\t\tfiles = (")
    for _, fpath in test_files:
        b_uuid, _ = build_files[fpath]
        fname = os.path.basename(fpath)
        pbx.append(f"\t\t\t\t{b_uuid} /* {fname} in Sources */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    pbx.append("\t\t};")
    
    pbx.append(f"\t\t{uitests_sources_phase} /* Sources */ = {{")
    pbx.append("\t\t\tisa = PBXSourcesBuildPhase;")
    pbx.append("\t\t\tbuildActionMask = 2147483647;")
    pbx.append("\t\t\tfiles = (")
    for _, fpath in uitest_files:
        b_uuid, _ = build_files[fpath]
        fname = os.path.basename(fpath)
        pbx.append(f"\t\t\t\t{b_uuid} /* {fname} in Sources */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    pbx.append("\t\t};")
    pbx.append("/* End PBXSourcesBuildPhase section */")
    pbx.append("")
    
    # XCBuildConfiguration
    pbx.append("/* Begin XCBuildConfiguration section */")
    
    # Project configurations
    pbx.append(f"\t\t{conf_debug_proj} /* Debug */ = {{")
    pbx.append("\t\t\tisa = XCBuildConfiguration;")
    pbx.append("\t\t\tbuildSettings = {")
    pbx.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    pbx.append("\t\t\t\tASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS = YES;")
    pbx.append("\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;")
    pbx.append("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
    pbx.append("\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;")
    pbx.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
    pbx.append("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
    pbx.append("\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_COMMA = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;")
    pbx.append("\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_OBJC_ROOTCLASS = YES_ERROR;")
    pbx.append("\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;")
    pbx.append("\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;")
    pbx.append("\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;")
    pbx.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
    pbx.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf\";")
    pbx.append("\t\t\t\tDERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER = NO;")
    pbx.append("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
    pbx.append("\t\t\t\tENABLE_TESTABILITY = YES;")
    pbx.append("\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;")
    pbx.append("\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;")
    pbx.append("\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;")
    pbx.append("\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
    pbx.append("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
    pbx.append("\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;")
    pbx.append("\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;")
    pbx.append("\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;")
    pbx.append("\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;")
    pbx.append("\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;")
    pbx.append("\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;")
    pbx.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 18.0;")
    pbx.append("\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;")
    pbx.append("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 15.0;")
    pbx.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
    pbx.append("\t\t\t\tMTL_FAST_MATH = YES;")
    pbx.append("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
    pbx.append("\t\t\t\tSDKROOT = iphoneos;")
    pbx.append("\t\t\t\tSTRING_CATALOG_GENERATE_SYMBOLS = YES;")
    pbx.append("\t\t\t\tSUPPORTS_MACCATALYST = YES;")
    pbx.append("\t\t\t\t\"CODE_SIGN_IDENTITY[sdk=macosx*]\" = \"-\";")
    pbx.append("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";")
    pbx.append("\t\t\t\tSWIFT_COMPILATION_MODE = singlefile;")
    pbx.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
    pbx.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
    pbx.append("\t\t\t\tSWIFT_VERSION = 5.0;")
    pbx.append("\t\t\t};")
    pbx.append("\t\t\tname = Debug;")
    pbx.append("\t\t};")
    
    pbx.append(f"\t\t{conf_release_proj} /* Release */ = {{")
    pbx.append("\t\t\tisa = XCBuildConfiguration;")
    pbx.append("\t\t\tbuildSettings = {")
    pbx.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    pbx.append("\t\t\t\tASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS = YES;")
    pbx.append("\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;")
    pbx.append("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
    pbx.append("\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;")
    pbx.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
    pbx.append("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
    pbx.append("\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_COMMA = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;")
    pbx.append("\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_OBJC_ROOTCLASS = YES_ERROR;")
    pbx.append("\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;")
    pbx.append("\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;")
    pbx.append("\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;")
    pbx.append("\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;")
    pbx.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
    pbx.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
    pbx.append("\t\t\t\tDERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER = NO;")
    pbx.append("\t\t\t\tENABLE_NS_ASSERTIONS = NO;")
    pbx.append("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
    pbx.append("\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;")
    pbx.append("\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;")
    pbx.append("\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
    pbx.append("\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;")
    pbx.append("\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;")
    pbx.append("\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;")
    pbx.append("\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;")
    pbx.append("\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;")
    pbx.append("\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;")
    pbx.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 18.0;")
    pbx.append("\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;")
    pbx.append("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 15.0;")
    pbx.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;")
    pbx.append("\t\t\t\tMTL_FAST_MATH = YES;")
    pbx.append("\t\t\t\tONLY_ACTIVE_ARCH = NO;")
    pbx.append("\t\t\t\tSDKROOT = iphoneos;")
    pbx.append("\t\t\t\tSTRING_CATALOG_GENERATE_SYMBOLS = YES;")
    pbx.append("\t\t\t\tSUPPORTS_MACCATALYST = YES;")
    pbx.append("\t\t\t\t\"CODE_SIGN_IDENTITY[sdk=macosx*]\" = \"-\";")
    pbx.append("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
    pbx.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
    pbx.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
    pbx.append("\t\t\t\tSWIFT_VERSION = 5.0;")
    pbx.append("\t\t\t};")
    pbx.append("\t\t\tname = Release;")
    pbx.append("\t\t};")
    
    # App configurations
    pbx.append(f"\t\t{conf_debug_app} /* Debug */ = {{")
    pbx.append("\t\t\tisa = XCBuildConfiguration;")
    pbx.append("\t\t\tbuildSettings = {")
    pbx.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
    pbx.append("\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
    pbx.append("\t\t\t\tASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS = YES;")
    pbx.append("\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;")
    pbx.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
    pbx.append("\t\t\t\t\"CODE_SIGN_IDENTITY[sdk=macosx*]\" = \"-\";")
    pbx.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
    pbx.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
    pbx.append("\t\t\t\tENABLE_HARDENED_RUNTIME = NO;")
    pbx.append("\t\t\t\tENABLE_TESTABILITY = YES;")
    pbx.append("\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;")
    pbx.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
    pbx.append("\t\t\t\tINFOPLIST_FILE = Vachanam/Info.plist;")
    pbx.append("\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;")
    pbx.append("\t\t\t\tMARKETING_VERSION = 1.0.0;")
    pbx.append("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
    pbx.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.vachanam.reader;")
    pbx.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    pbx.append("\t\t\t\tSTRING_CATALOG_GENERATE_SYMBOLS = YES;")
    pbx.append("\t\t\t\tSUPPORTS_MACCATALYST = YES;")
    pbx.append("\t\t\t\tSWIFT_COMPILATION_MODE = singlefile;")
    pbx.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
    pbx.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"2\";")
    pbx.append("\t\t\t};")
    pbx.append("\t\t\tname = Debug;")
    pbx.append("\t\t};")
    
    # App release
    pbx.append(f"\t\t{conf_release_app} /* Release */ = {{")
    pbx.append("\t\t\tisa = XCBuildConfiguration;")
    pbx.append("\t\t\tbuildSettings = {")
    pbx.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
    pbx.append("\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
    pbx.append("\t\t\t\tASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS = YES;")
    pbx.append("\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;")
    pbx.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
    pbx.append("\t\t\t\t\"CODE_SIGN_IDENTITY[sdk=macosx*]\" = \"-\";")
    pbx.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
    pbx.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
    pbx.append("\t\t\t\tENABLE_TESTABILITY = YES;")
    pbx.append("\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;")
    pbx.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
    pbx.append("\t\t\t\tINFOPLIST_FILE = Vachanam/Info.plist;")
    pbx.append("\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;")
    pbx.append("\t\t\t\tMARKETING_VERSION = 1.0.0;")
    pbx.append("\t\t\t\tONLY_ACTIVE_ARCH = NO;")
    pbx.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.vachanam.reader;")
    pbx.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    pbx.append("\t\t\t\tSTRING_CATALOG_GENERATE_SYMBOLS = YES;")
    pbx.append("\t\t\t\tSUPPORTS_MACCATALYST = YES;")
    pbx.append("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
    pbx.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
    pbx.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"2\";")
    pbx.append("\t\t\t};")
    pbx.append("\t\t\tname = Release;")
    pbx.append("\t\t};")
    
    # Tests configurations
    pbx.append(f"\t\t{conf_debug_tests} /* Debug */ = {{")
    pbx.append("\t\t\tisa = XCBuildConfiguration;")
    pbx.append("\t\t\tbuildSettings = {")
    pbx.append("\t\t\t\tBUNDLE_LOADER = \"$(TEST_HOST)\";")
    pbx.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
    pbx.append("\t\t\t\t\"CODE_SIGN_IDENTITY[sdk=macosx*]\" = \"-\";")
    pbx.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
    pbx.append("\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;")
    pbx.append("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
    pbx.append("\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;")
    pbx.append("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
    pbx.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.vachanam.reader.tests;")
    pbx.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    pbx.append("\t\t\t\tSTRING_CATALOG_GENERATE_SYMBOLS = YES;")
    pbx.append("\t\t\t\tSWIFT_COMPILATION_MODE = singlefile;")
    pbx.append(f"\t\t\t\tTEST_HOST = \"$(BUILT_PRODUCTS_DIR)/Vachanam.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Vachanam\";")
    pbx.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"2\";")
    pbx.append("\t\t\t\tSUPPORTS_MACCATALYST = YES;")
    pbx.append("\t\t\t};")
    pbx.append("\t\t\tname = Debug;")
    pbx.append("\t\t};")
    
    pbx.append(f"\t\t{conf_release_tests} /* Release */ = {{")
    pbx.append("\t\t\tisa = XCBuildConfiguration;")
    pbx.append("\t\t\tbuildSettings = {")
    pbx.append("\t\t\t\tBUNDLE_LOADER = \"$(TEST_HOST)\";")
    pbx.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
    pbx.append("\t\t\t\t\"CODE_SIGN_IDENTITY[sdk=macosx*]\" = \"-\";")
    pbx.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
    pbx.append("\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;")
    pbx.append("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
    pbx.append("\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;")
    pbx.append("\t\t\t\tONLY_ACTIVE_ARCH = NO;")
    pbx.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.vachanam.reader.tests;")
    pbx.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    pbx.append("\t\t\t\tSTRING_CATALOG_GENERATE_SYMBOLS = YES;")
    pbx.append("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
    pbx.append(f"\t\t\t\tTEST_HOST = \"$(BUILT_PRODUCTS_DIR)/Vachanam.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Vachanam\";")
    pbx.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"2\";")
    pbx.append("\t\t\t\tSUPPORTS_MACCATALYST = YES;")
    pbx.append("\t\t\t};")
    pbx.append("\t\t\tname = Release;")
    pbx.append("\t\t};")
    
    # UITests configurations
    pbx.append(f"\t\t{conf_debug_uitests} /* Debug */ = {{")
    pbx.append("\t\t\tisa = XCBuildConfiguration;")
    pbx.append("\t\t\tbuildSettings = {")
    pbx.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
    pbx.append("\t\t\t\t\"CODE_SIGN_IDENTITY[sdk=macosx*]\" = \"-\";")
    pbx.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
    pbx.append("\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;")
    pbx.append("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
    pbx.append("\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;")
    pbx.append("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
    pbx.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.vachanam.reader.uitests;")
    pbx.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    pbx.append("\t\t\t\tSTRING_CATALOG_GENERATE_SYMBOLS = YES;")
    pbx.append("\t\t\t\tSWIFT_COMPILATION_MODE = singlefile;")
    pbx.append(f"\t\t\t\tTEST_TARGET_NAME = Vachanam;")
    pbx.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"2\";")
    pbx.append("\t\t\t\tSUPPORTS_MACCATALYST = YES;")
    pbx.append("\t\t\t};")
    pbx.append("\t\t\tname = Debug;")
    pbx.append("\t\t};")
    
    pbx.append(f"\t\t{conf_release_uitests} /* Release */ = {{")
    pbx.append("\t\t\tisa = XCBuildConfiguration;")
    pbx.append("\t\t\tbuildSettings = {")
    pbx.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
    pbx.append("\t\t\t\t\"CODE_SIGN_IDENTITY[sdk=macosx*]\" = \"-\";")
    pbx.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
    pbx.append("\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;")
    pbx.append("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
    pbx.append("\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;")
    pbx.append("\t\t\t\tONLY_ACTIVE_ARCH = NO;")
    pbx.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.vachanam.reader.uitests;")
    pbx.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    pbx.append("\t\t\t\tSTRING_CATALOG_GENERATE_SYMBOLS = YES;")
    pbx.append("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
    pbx.append(f"\t\t\t\tTEST_TARGET_NAME = Vachanam;")
    pbx.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"2\";")
    pbx.append("\t\t\t\tSUPPORTS_MACCATALYST = YES;")
    pbx.append("\t\t\t};")
    pbx.append("\t\t\tname = Release;")
    pbx.append("\t\t};")
    pbx.append("/* End XCBuildConfiguration section */")
    pbx.append("")
    
    # XCConfigurationList section
    pbx.append("/* Begin XCConfigurationList section */")
    pbx.append(f"\t\t{config_list_proj} /* Build configuration list for PBXProject \"Vachanam\" */ = {{")
    pbx.append("\t\t\tisa = XCConfigurationList;")
    pbx.append("\t\t\tbuildConfigurations = (")
    pbx.append(f"\t\t\t\t{conf_debug_proj} /* Debug */,")
    pbx.append(f"\t\t\t\t{conf_release_proj} /* Release */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    pbx.append("\t\t\tdefaultConfigurationName = Release;")
    pbx.append("\t\t};")
    
    pbx.append(f"\t\t{config_list_app} /* Build configuration list for PBXNativeTarget \"Vachanam\" */ = {{")
    pbx.append("\t\t\tisa = XCConfigurationList;")
    pbx.append("\t\t\tbuildConfigurations = (")
    pbx.append(f"\t\t\t\t{conf_debug_app} /* Debug */,")
    pbx.append(f"\t\t\t\t{conf_release_app} /* Release */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    pbx.append("\t\t\tdefaultConfigurationName = Release;")
    pbx.append("\t\t};")
    
    pbx.append(f"\t\t{config_list_tests} /* Build configuration list for PBXNativeTarget \"VachanamTests\" */ = {{")
    pbx.append("\t\t\tisa = XCConfigurationList;")
    pbx.append("\t\t\tbuildConfigurations = (")
    pbx.append(f"\t\t\t\t{conf_debug_tests} /* Debug */,")
    pbx.append(f"\t\t\t\t{conf_release_tests} /* Release */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    pbx.append("\t\t\tdefaultConfigurationName = Release;")
    pbx.append("\t\t};")
    
    pbx.append(f"\t\t{config_list_uitests} /* Build configuration list for PBXNativeTarget \"VachanamUITests\" */ = {{")
    pbx.append("\t\t\tisa = XCConfigurationList;")
    pbx.append("\t\t\tbuildConfigurations = (")
    pbx.append(f"\t\t\t\t{conf_debug_uitests} /* Debug */,")
    pbx.append(f"\t\t\t\t{conf_release_uitests} /* Release */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    pbx.append("\t\t\tdefaultConfigurationName = Release;")
    pbx.append("\t\t};")
    pbx.append("/* End XCConfigurationList section */")
    pbx.append("")
    
    pbx.append("\t};")
    pbx.append(f"\trootObject = {proj_uuid} /* Project object */;")
    pbx.append("}")
    
    pbx_content = "\n".join(pbx)
    with open(os.path.join(proj_dir, "project.pbxproj"), "w") as f:
        f.write(pbx_content)
        
    # Generate xcshareddata scheme
    scheme_dir = os.path.join(proj_dir, "xcshareddata", "xcschemes")
    os.makedirs(scheme_dir, exist_ok=True)
    scheme_xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1530"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{app_target_uuid}"
               BuildableName = "Vachanam.app"
               BlueprintName = "Vachanam"
               ReferencedContainer = "container:Vachanam.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "NO"
            buildForProfiling = "NO"
            buildForArchiving = "NO"
            buildForAnalyzing = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{tests_target_uuid}"
               BuildableName = "VachanamTests.xctest"
               BlueprintName = "VachanamTests"
               ReferencedContainer = "container:Vachanam.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "NO"
            buildForProfiling = "NO"
            buildForArchiving = "NO"
            buildForAnalyzing = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{uitests_target_uuid}"
               BuildableName = "VachanamUITests.xctest"
               BlueprintName = "VachanamUITests"
               ReferencedContainer = "container:Vachanam.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{tests_target_uuid}"
               BuildableName = "VachanamTests.xctest"
               BlueprintName = "VachanamTests"
               ReferencedContainer = "container:Vachanam.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
      <EnvironmentVariables>
         <EnvironmentVariable
            key = "MLX_METAL_GPU_ARCH"
            value = "appleg14g"
            isEnabled = "YES">
         </EnvironmentVariable>
      </EnvironmentVariables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useLaunchSchemeArgsEnv = "YES"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target_uuid}"
            BuildableName = "Vachanam.app"
            BlueprintName = "Vachanam"
            ReferencedContainer = "container:Vachanam.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
      <EnvironmentVariables>
         <EnvironmentVariable
            key = "MLX_METAL_GPU_ARCH"
            value = "appleg14g"
            isEnabled = "YES">
         </EnvironmentVariable>
      </EnvironmentVariables>
   </LaunchAction>
</Scheme>
"""
    with open(os.path.join(scheme_dir, "Vachanam.xcscheme"), "w") as f:
        f.write(scheme_xml)
        
    print("Successfully generated Vachanam.xcodeproj and Vachanam.xcscheme")

if __name__ == "__main__":
    create_project()
    print("Xcode project generated successfully.")
