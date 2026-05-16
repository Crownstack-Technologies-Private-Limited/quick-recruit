require 'open-uri'

class ResumeExtractor
  MIN_USABLE_LENGTH = 200  # chars; below this, treat as extraction failure

  Result = Struct.new(:text, :usable, :reason, keyword_init: true) do
    def usable? = usable
  end

  def self.extract(candidate)
    new(candidate).extract
  end

  def initialize(candidate)
    @candidate = candidate
  end

  def extract
    return Result.new(text: '', usable: false, reason: 'no_resume_attached') unless @candidate.resume.attached?

    text = read_pdf_text
    if text.length < MIN_USABLE_LENGTH
      Result.new(text: text, usable: false, reason: 'extracted_text_too_short')
    else
      Result.new(text: text, usable: true, reason: nil)
    end
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError => e
    Result.new(text: '', usable: false, reason: "pdf_error:#{e.class.name.demodulize}")
  rescue Aws::S3::Errors::Forbidden, Aws::S3::Errors::AccessDenied => e
    Result.new(text: '', usable: false, reason: "s3_access_denied:#{e.class.name.demodulize}")
  rescue StandardError => e
    Result.new(text: '', usable: false, reason: "download_error:#{e.class.name.demodulize}")
  end

  private

  def read_pdf_text
    @candidate.resume.open do |file|
      reader = PDF::Reader.new(file)
      reader.pages.map(&:text).join("\n").strip
    end
  rescue Aws::S3::Errors::Forbidden, Aws::S3::Errors::AccessDenied
    # Direct GetObject blocked by bucket policy — fall back to presigned URL download
    read_pdf_via_presigned_url
  end

  def read_pdf_via_presigned_url
    url = @candidate.resume.blob.url(expires_in: 5.minutes)
    URI.open(url, "rb") do |file|
      reader = PDF::Reader.new(file)
      reader.pages.map(&:text).join("\n").strip
    end
  end
end
