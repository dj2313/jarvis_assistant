# Contributing to Friday Assistant

Thank you for your interest in contributing to Friday Assistant! This document provides guidelines and instructions for contributing to the project.

## 📋 Code of Conduct

We are committed to providing a welcoming and inspiring community for all. Please read and adhere to our Code of Conduct when interacting with the community.

## 🚀 How to Contribute

### 1. Reporting Bugs
If you encounter a bug, please create an issue with:
- **Title:** Clear, concise description of the bug
- **Description:** Detailed explanation of the issue
- **Steps to Reproduce:** Clear steps to reproduce the bug
- **Expected Behavior:** What should happen
- **Actual Behavior:** What actually happens
- **Screenshots/Videos:** If applicable
- **Environment:** Flutter version, Dart version, OS, device info

### 2. Suggesting Enhancements
We welcome feature requests and suggestions:
- **Title:** Clear description of the feature
- **Description:** Detailed explanation of what you'd like
- **Rationale:** Why this feature would be useful
- **Example Use Cases:** How users might use this feature

### 3. Code Contributions

#### Getting Started
1. **Fork the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/jarvis_assistant.git
   cd jarvis_assistant
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```

3. **Make your changes** following the code style guidelines

4. **Test your changes**
   ```bash
   flutter analyze
   flutter test
   ```

5. **Commit your changes**
   ```bash
   git commit -m 'Add amazing feature'
   ```

6. **Push to your branch**
   ```bash
   git push origin feature/amazing-feature
   ```

7. **Open a Pull Request** with a clear description

#### Code Style Guidelines

- **Dart:** Follow the [Effective Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- **Formatting:** Use `dart format` to format your code
- **Linting:** Ensure no warnings from `flutter analyze`
- **Naming:** Use clear, descriptive names for variables, functions, and classes
- **Comments:** Add meaningful comments for complex logic
- **Documentation:** Update documentation for new features

#### Commit Message Guidelines

- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line

#### Pull Request Guidelines

- **Title:** Clear, descriptive PR title
- **Description:** Detailed explanation of changes
- **Related Issues:** Link any related issues (e.g., Fixes #123)
- **Testing:** Describe how you tested the changes
- **Screenshots:** Include before/after screenshots if UI changes
- **Checklist:**
  - [ ] Code follows style guidelines
  - [ ] Tests pass (`flutter test`)
  - [ ] No new warnings from `flutter analyze`
  - [ ] README updated (if applicable)
  - [ ] Documentation updated (if applicable)

## 🔧 Development Setup

### Prerequisites
- Flutter SDK v3.10+
- Dart 3.0+
- Android Studio or VS Code with Flutter extension
- Supabase account

### Environment Configuration
1. Create a `.env` file in the root directory
2. Install dependencies: `flutter pub get`
3. Run the app: `flutter run`

## 🧪 Testing

Write tests for new features:
- Run all tests: `flutter test`
- Run specific test file: `flutter test test/services/friday_brain_service_test.dart`

## 📚 Documentation

- Update `README.md` for user-facing changes
- Add/update inline code comments
- Update API documentation in `docs/` folder
- Include examples for new features

## 💬 Getting Help

- **Discussions:** Check GitHub Discussions for Q&A
- **Issues:** Search existing issues before creating a new one
- **Documentation:** Check `docs/` folder for detailed information

## 📝 License

By contributing to Friday Assistant, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for making Friday Assistant better! 🚀**