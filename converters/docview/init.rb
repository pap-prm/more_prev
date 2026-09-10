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
# 1.0.0
#       - initial version for Redmine 6.1.x
#

require_relative 'lib/docview'

RedmineMorePreviews::Converter.register :docview do
  name           'DocView'
  author         'Plugin Author'
  description    'Preview documents using embedded PDF viewer'
  version        '1.0.0'
  url            'https://github.com/example/redmine_more_previews_docview'
  author_url     'https://github.com/example'
                 
  settings       :logo    => "logo.png",
                 :partial => 'settings/redmine_more_previews/docview/settings'
                 
  mime_types     :pdf  => {:formats => [:html, :inline], :mime => "application/pdf", :icon => "pdf.png"},
                 :doc  => {:formats => [:html, :inline], :mime => "application/msword", :synonyms => ["application/vnd.ms-word"], :icon => "doc.png"},
                 :docx => {:formats => [:html, :inline], :mime => "application/vnd.openxmlformats-officedocument.wordprocessingml.document", :icon => "docx.png"},
                 :ppt  => {:formats => [:html, :inline], :mime => "application/mspowerpoint"},
                 :pptx => {:formats => [:html, :inline], :mime => "application/vnd.openxmlformats-officedocument.presentationml.presentation"},
                 :xls  => {:formats => [:html, :inline], :mime => "application/msexcel", :synonyms => ["application/vnd.ms-excel"], :icon => "xls.png"},
                 :xlsx => {:formats => [:html, :inline], :mime => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", :icon => "xlsx.png"},
                 :odt  => {:formats => [:html, :inline], :mime => "application/vnd.oasis.opendocument.text"},
                 :ods  => {:formats => [:html, :inline], :mime => "application/vnd.oasis.opendocument.spreadsheet"},
                 :odp  => {:formats => [:html, :inline], :mime => "application/vnd.oasis.opendocument.presentation"}
end

