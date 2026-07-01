# ClipboardManager development helpers

.PHONY: build test clean lint format run

# Build the project
build:
	cd ClipboardManager && swift build

# Run all tests
test:
	cd ClipboardManager && swift test

# Build and run the app (debug)
run:
	cd ClipboardManager && swift run

# Clean build artifacts
clean:
	cd ClipboardManager && swift package clean
	rm -rf ClipboardManager/.build

# Run SwiftLint (install: brew install swiftlint)
lint:
	swiftlint

# Auto-fix lint issues
lint-fix:
	swiftlint --fix

# Run SwiftFormat (install: brew install swiftformat)
format:
	swiftformat ClipboardManager/Sources ClipboardManager/Tests

# Check formatting without modifying files
format-check:
	swiftformat --lint ClipboardManager/Sources ClipboardManager/Tests

# Build the .app bundle
app:
	cd ClipboardManager && swift build
	cd ClipboardManager && .build/build-app.sh

# Run all quality checks
check: lint format-check build test
