# encoding: utf-8
#
# RedmineMorePreviews converter to preview documents with embedded viewer
#
# Copyright © 2024 Stephan Wenzel <stephan.wenzel@drwpatent.de>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

class DocView < RedmineMorePreviews::Conversion

  #---------------------------------------------------------------------------------
  # delegates
  #---------------------------------------------------------------------------------
  delegate :url_for, :to => "Rails.application.routes.url_helpers"
           
  #---------------------------------------------------------------------------------
  # constants
  #---------------------------------------------------------------------------------
  SUPPORTED_MIMES = {
    "application/pdf" => :pdf,
    "application/msword" => :doc,
    "application/vnd.ms-word" => :doc,
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => :docx,
    "application/mspowerpoint" => :ppt,
    "application/vnd.ms-powerpoint" => :ppt,
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" => :pptx,
    "application/msexcel" => :xls,
    "application/vnd.ms-excel" => :xls,
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => :xlsx,
    "application/vnd.oasis.opendocument.text" => :odt,
    "application/vnd.oasis.opendocument.spreadsheet" => :ods,
    "application/vnd.oasis.opendocument.presentation" => :odp
  }.freeze
  
  #---------------------------------------------------------------------------------
  # check: is DocView available?
  #---------------------------------------------------------------------------------
  def status
    [:text_docview_available, true]
  end
  
  ########################################################################################
  #
  # convert
  #
  ########################################################################################
  def convert
    case preview_format
    when "html", "inline"
      render_document_viewer
    else
      # Fallback: just pass through the file
      FileUtils.cp(source, tmptarget)
    end
  end #def
  
  #---------------------------------------------------------------------------------
  # render_document_viewer
  #---------------------------------------------------------------------------------
  def render_document_viewer
    mime_type = Marcel::MimeType.for(Pathname.new(source), name: File.basename(source))
    doc_type = SUPPORTED_MIMES[mime_type] || :unknown
    
    # Generate download URL for the document
    download_url = case object["object"]
    when Attachment
      url_for(
        controller: "attachments",
        action: "download",
        id: object["object"].id,
        filename: object["object"].filename,
        only_path: true
      )
    when Repository
      url_for(
        controller: "repositories",
        action: "raw",
        id: object["object"].project.identifier,
        repository_id: object["object"].identifier_param,
        rev: object["rev"],
        path: object["path"],
        only_path: true
      )
    else
      nil
    end
    
    # Build HTML viewer based on document type
    html_content = build_viewer_html(doc_type, download_url, mime_type)
    
    File.open(tmptarget, "wb") { |f| f.write html_content }
  end #def
  
  #---------------------------------------------------------------------------------
  # build_viewer_html
  #---------------------------------------------------------------------------------
  def build_viewer_html(doc_type, download_url, mime_type)
    filename = File.basename(source)
    
    case doc_type
    when :pdf
      build_pdf_viewer(download_url, filename)
    when :doc, :docx, :odt
      build_office_viewer(download_url, filename, mime_type, "Word Document")
    when :xls, :xlsx, :ods
      build_office_viewer(download_url, filename, mime_type, "Spreadsheet")
    when :ppt, :pptx, :odp
      build_office_viewer(download_url, filename, mime_type, "Presentation")
    else
      build_fallback_viewer(filename, mime_type, download_url)
    end
  end #def
  
  #---------------------------------------------------------------------------------
  # build_pdf_viewer - Creates an embedded PDF viewer using HTML5
  #---------------------------------------------------------------------------------
  def build_pdf_viewer(pdf_url, filename)
    <<-HTML.html_safe
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>#{CGI.escapeHTML(filename)}</title>
  <style>
    body { margin: 0; padding: 0; background: #f0f0f0; }
    .pdf-container { 
      width: 100%; 
      height: 100vh; 
      display: flex;
      flex-direction: column;
    }
    .pdf-header {
      background: #333;
      color: white;
      padding: 10px 15px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .pdf-title { font-size: 14px; font-weight: bold; }
    .pdf-actions a {
      color: white;
      text-decoration: none;
      margin-left: 15px;
      padding: 5px 10px;
      background: #555;
      border-radius: 3px;
      font-size: 12px;
    }
    .pdf-actions a:hover { background: #666; }
    .pdf-frame { 
      flex: 1; 
      width: 100%; 
      border: none;
      background: white;
    }
    .fallback-message {
      padding: 20px;
      text-align: center;
      background: #fff;
      margin: 10px;
      border-radius: 5px;
    }
    .fallback-message a {
      color: #0066cc;
      font-weight: bold;
    }
  </style>
</head>
<body>
  <div class="pdf-container">
    <div class="pdf-header">
      <span class="pdf-title">#{CGI.escapeHTML(filename)}</span>
      <div class="pdf-actions">
        <a href="#{pdf_url}" download>Download</a>
        <a href="#{pdf_url}" target="_blank">Open in new tab</a>
      </div>
    </div>
    <object class="pdf-frame" data="#{pdf_url}#toolbar=0&navpanes=0" type="application/pdf">
      <div class="fallback-message">
        <p>Your browser does not support embedded PDF viewing.</p>
        <p><a href="#{pdf_url}" download>Click here to download the PDF</a></p>
      </div>
    </object>
  </div>
  <script>
    // Fallback for browsers that don't support PDF embedding
    document.querySelector('.pdf-frame').addEventListener('error', function() {
      this.style.display = 'none';
      var fallback = document.querySelector('.fallback-message');
      if (fallback) fallback.style.display = 'block';
    });
  </script>
</body>
</html>
    HTML
  end #def
  
  #---------------------------------------------------------------------------------
  # build_office_viewer - Creates viewer for Office documents
  #---------------------------------------------------------------------------------
  def build_office_viewer(doc_url, filename, mime_type, doc_description)
    # Try to use Google Docs Viewer or Microsoft Office Online Viewer
    google_viewer_url = "https://docs.google.com/viewer?url=#{URI.encode_www_form_component(doc_url)}&embedded=true"
    office_viewer_url = "https://view.officeapps.live.com/op/view.aspx?src=#{URI.encode_www_form_component(doc_url)}"
    
    <<-HTML.html_safe
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>#{CGI.escapeHTML(filename)}</title>
  <style>
    body { margin: 0; padding: 0; background: #f0f0f0; }
    .doc-container { 
      width: 100%; 
      height: 100vh; 
      display: flex;
      flex-direction: column;
    }
    .doc-header {
      background: #2b579a;
      color: white;
      padding: 10px 15px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .doc-title { font-size: 14px; font-weight: bold; }
    .doc-type { 
      font-size: 11px; 
      opacity: 0.8; 
      margin-left: 10px;
      background: rgba(255,255,255,0.2);
      padding: 2px 8px;
      border-radius: 3px;
    }
    .doc-actions a {
      color: white;
      text-decoration: none;
      margin-left: 15px;
      padding: 5px 10px;
      background: rgba(255,255,255,0.2);
      border-radius: 3px;
      font-size: 12px;
    }
    .doc-actions a:hover { background: rgba(255,255,255,0.3); }
    .doc-frame { 
      flex: 1; 
      width: 100%; 
      border: none;
      background: white;
    }
    .viewer-selector {
      padding: 20px;
      background: #fff;
      margin: 10px;
      border-radius: 5px;
      box-shadow: 0 2px 5px rgba(0,0,0,0.1);
    }
    .viewer-selector h3 { margin-top: 0; color: #333; }
    .viewer-selector a {
      display: inline-block;
      margin: 10px 10px 10px 0;
      padding: 10px 20px;
      background: #0066cc;
      color: white;
      text-decoration: none;
      border-radius: 5px;
    }
    .viewer-selector a:hover { background: #0055aa; }
    .viewer-selector a.secondary {
      background: #666;
    }
    .download-section {
      padding: 15px 20px;
      background: #f9f9f9;
      border-top: 1px solid #ddd;
    }
  </style>
</head>
<body>
  <div class="doc-container">
    <div class="doc-header">
      <div>
        <span class="doc-title">#{CGI.escapeHTML(filename)}</span>
        <span class="doc-type">#{doc_description}</span>
      </div>
      <div class="doc-actions">
        <a href="#{doc_url}" download>Download</a>
        <a href="#{doc_url}" target="_blank">Open original</a>
      </div>
    </div>
    
    <!-- Try Google Docs Viewer first -->
    <iframe class="doc-frame" src="#{google_viewer_url}" sandbox="allow-scripts allow-same-origin allow-forms">
      Your browser does not support iframes.
    </iframe>
    
    <div class="download-section">
      <strong>Alternative viewers:</strong> If the document doesn't display properly, try:
      <div class="viewer-selector">
        <a href="#{office_viewer_url}" target="_blank">Microsoft Office Online Viewer</a>
        <a href="#{doc_url}" download class="secondary">Download File</a>
      </div>
    </div>
  </div>
  
  <script>
    // Auto-hide the download section if iframe loads successfully
    var iframe = document.querySelector('.doc-frame');
    var downloadSection = document.querySelector('.download-section');
    
    iframe.addEventListener('load', function() {
      // Give it time to potentially show an error
      setTimeout(function() {
        downloadSection.style.display = 'none';
      }, 2000);
    });
    
    iframe.addEventListener('error', function() {
      downloadSection.style.display = 'block';
    });
  </script>
</body>
</html>
    HTML
  end #def
  
  #---------------------------------------------------------------------------------
  # build_fallback_viewer - Generic fallback for unsupported formats
  #---------------------------------------------------------------------------------
  def build_fallback_viewer(filename, mime_type, download_url)
    <<-HTML.html_safe
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>#{CGI.escapeHTML(filename)}</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      background: #f5f5f5;
      padding: 40px 20px;
      margin: 0;
    }
    .container {
      max-width: 600px;
      margin: 0 auto;
      background: white;
      padding: 40px;
      border-radius: 8px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
      text-align: center;
    }
    .icon {
      font-size: 64px;
      margin-bottom: 20px;
    }
    h1 {
      color: #333;
      font-size: 24px;
      margin-bottom: 10px;
    }
    .mime-type {
      color: #666;
      font-size: 14px;
      font-family: monospace;
      background: #f0f0f0;
      padding: 5px 10px;
      border-radius: 3px;
      display: inline-block;
      margin-bottom: 20px;
    }
    .filename {
      word-break: break-all;
      color: #0066cc;
      margin-bottom: 30px;
    }
    .actions {
      display: flex;
      gap: 15px;
      justify-content: center;
      flex-wrap: wrap;
    }
    .btn {
      padding: 12px 24px;
      border-radius: 5px;
      text-decoration: none;
      font-weight: bold;
      transition: background 0.2s;
    }
    .btn-primary {
      background: #0066cc;
      color: white;
    }
    .btn-primary:hover {
      background: #0055aa;
    }
    .btn-secondary {
      background: #e0e0e0;
      color: #333;
    }
    .btn-secondary:hover {
      background: #d0d0d0;
    }
    .info {
      margin-top: 30px;
      padding-top: 20px;
      border-top: 1px solid #eee;
      color: #666;
      font-size: 13px;
      line-height: 1.6;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="icon">📄</div>
    <h1>Document Preview</h1>
    <div class="mime-type">#{CGI.escapeHTML(mime_type.to_s)}</div>
    <p class="filename">#{CGI.escapeHTML(filename)}</p>
    
    <div class="actions">
      <a href="#{download_url}" download class="btn btn-primary">Download File</a>
      <a href="#{download_url}" target="_blank" class="btn btn-secondary">Open in New Tab</a>
    </div>
    
    <div class="info">
      <p>This file format cannot be displayed directly in the browser.</p>
      <p>Please download the file to view it with an appropriate application.</p>
    </div>
  </div>
</body>
</html>
    HTML
  end #def
  
end #class
