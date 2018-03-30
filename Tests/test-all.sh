#!/bin/sh

set -e
set -o pipefail

SCRIPT_DIR="$(dirname $0)"
CODE_SIGNING="CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO"

if [[ -z "${IOS_VERSION}" ]] ; then
	IOS_VERSION="11.3"
fi

IOS_DESTINATION="platform=iOS Simulator,name=iPhone 8,OS=${IOS_VERSION}"
MACOS_DESTINATION="platform=OS X,arch=x86_64"

# Use xcpretty on CI of if manually enabled
if [ "${CI}" == "true" ] && [[ -z "${USE_XCPRETTY}" ]] ; then
	USE_XCPRETTY="true"
fi

if [ "${USE_XCPRETTY}" == "true" ] ; then
	echo "Using xcpretty..."
	XCPRETTY=" | xcpretty -c"
else
	XCPRETTY=""
fi

# Run all of the tests

POD_TEST_IOS="xcodebuild -workspace ./${SCRIPT_DIR}/iOS/CocoaAsyncSocket.xcworkspace -scheme CocoaAsyncSocketTestsiOS -sdk iphonesimulator -destination \"${IOS_DESTINATION}\" test ${CODE_SIGNING} ${XCPRETTY}"
POD_TEST_MAC="xcodebuild -workspace ./${SCRIPT_DIR}/Mac/CocoaAsyncSocket.xcworkspace -scheme CocoaAsyncSocketTestsMac -sdk macosx -destination \"${MACOS_DESTINATION}\" test ${CODE_SIGNING} ${XCPRETTY}"
FRAMEWORK_IOS="xcodebuild -project ./${SCRIPT_DIR}/Framework/CocoaAsyncSocketTests.xcodeproj -scheme \"CocoaAsyncSocketTests (iOS)\" -sdk iphonesimulator -destination \"${IOS_DESTINATION}\" test ${CODE_SIGNING} ${XCPRETTY}"
FRAMEWORK_MAC="xcodebuild -project ./${SCRIPT_DIR}/Framework/CocoaAsyncSocketTests.xcodeproj -scheme \"CocoaAsyncSocketTests (macOS)\" -sdk macosx -destination \"${MACOS_DESTINATION}\" test ${CODE_SIGNING} ${XCPRETTY}"

declare -a TESTS=("${POD_TEST_IOS}" "${POD_TEST_MAC}" "${FRAMEWORK_IOS}" "${FRAMEWORK_MAC}")

for TEST in "${TESTS[@]}"
do
   echo "Running test: ${TEST}"
   eval ${TEST}	
done
