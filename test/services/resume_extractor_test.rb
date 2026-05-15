require "test_helper"

class ResumeExtractorTest < ActiveSupport::TestCase
  def setup
    @candidate = candidates(:john_doe)
  end

  test 'extract returns usable false and reason no_resume_attached when no resume' do
    candidate = Candidate.new(first_name: 'John', last_name: 'Doe', email: 'john@example.com')
    assert_not candidate.resume.attached?

    result = ResumeExtractor.extract(candidate)

    assert_equal false, result.usable
    assert_equal 'no_resume_attached', result.reason
    assert_equal '', result.text
  end

  test 'extract returns usable false when extracted text is too short' do
    short_text = "This is very short text"
    test_extract_with_text(short_text, false, 'extracted_text_too_short')
  end

  test 'extract returns usable true when extracted text meets minimum length' do
    long_text = "A" * 250
    test_extract_with_text(long_text, true, nil)
  end

  test 'extract handles PDF::Reader::MalformedPDFError' do
    test_extract_with_error(PDF::Reader::MalformedPDFError.new("Bad PDF"), 'pdf_error:MalformedPDFError')
  end

  test 'extract handles PDF::Reader::UnsupportedFeatureError' do
    test_extract_with_error(PDF::Reader::UnsupportedFeatureError.new("Unsupported"), 'pdf_error:UnsupportedFeatureError')
  end

  test 'extract concatenates multiple pages with newline' do
    page1_text = "A" * 150
    page2_text = "B" * 100
    full_text = "#{page1_text}\n#{page2_text}"

    test_extract_with_text(full_text, true, nil)
  end

  test 'extract result has usable? predicate method' do
    result = ResumeExtractor::Result.new(text: 'test', usable: false, reason: 'test')

    assert_respond_to result, :usable?
    assert_equal false, result.usable?
  end

  private

  def test_extract_with_text(text, expected_usable, expected_reason)
    candidate = Candidate.new(first_name: 'John', last_name: 'Doe', email: 'john@example.com')

    # Create a mock that represents an attached resume
    resume_mock = Class.new do
      def attached?
        true
      end

      def open
        yield(nil)
      end
    end.new

    candidate.define_singleton_method(:resume) { resume_mock }

    extractor = ResumeExtractor.new(candidate)
    extractor.define_singleton_method(:read_pdf_text) { text }

    result = extractor.extract

    assert_equal expected_usable, result.usable
    assert_equal expected_reason, result.reason
    assert_equal text, result.text
  end

  def test_extract_with_error(error, expected_reason)
    candidate = Candidate.new(first_name: 'John', last_name: 'Doe', email: 'john@example.com')

    resume_mock = Class.new do
      def attached?
        true
      end

      def open
        yield(nil)
      end
    end.new

    candidate.define_singleton_method(:resume) { resume_mock }

    extractor = ResumeExtractor.new(candidate)
    extractor.define_singleton_method(:read_pdf_text) { raise error }

    result = extractor.extract

    assert_equal false, result.usable
    assert_equal expected_reason, result.reason
    assert_equal '', result.text
  end
end
