require 'nokogiri'
require 'open-uri'
require 'sqlite3'
require 'logger'
require 'date'
require 'cgi'

# Set up a logger to log the scraped data
logger = Logger.new(STDOUT)

# URL of the Glenorchy City Council planning applications page
url = 'https://www.kentish.tas.gov.au/services/building-and-planning-services/planningapp'

# Step 1: Fetch the page content
begin
  logger.info("Fetching page content from: #{url}")
  page_html = open(url).read
  logger.info("Successfully fetched page content.")
rescue => e
  logger.error("Failed to fetch page content: #{e}")
  exit
end

# Step 2: Parse the page content using Nokogiri
doc = Nokogiri::HTML(page_html)

# Step 3: Initialize the SQLite database
db = SQLite3::Database.new "data.sqlite"

# Create table
db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS kentish (
    id INTEGER PRIMARY KEY,
    description TEXT,
    date_scraped TEXT,
    date_received TEXT,
    on_notice_to TEXT,
    address TEXT,
    council_reference TEXT,
    applicant TEXT,
    owner TEXT,
    stage_description TEXT,
    stage_status TEXT,
    document_description TEXT,
    title_reference TEXT
  );
SQL

# Define variables for storing extracted data for each entry
address = ''  
description = ''
on_notice_to = ''
title_reference = ''
date_received = ''
council_reference = ''
applicant = ''
owner = ''
stage_description = ''
stage_status = ''
document_description = ''
date_scraped = Date.today.to_s


# Loop through each application listed in the page
doc.css('.generic-list__item').each do |item|
  # Extract the council reference, address, description, closing date, and PDF link
  council_reference = item.at_css('.generic-list__title a').text.match(/^K-\S+/).to_s.strip
  address = item.at_css('.generic-list__title a').text.match(/(\d+.*?[\w\s]+)$/).to_s.strip
  document_description = item.at_css('.generic-list__title a').text.match(/- (.*?) \(submissions/).to_s.strip
  on_notice_to = item.at_css('.generic-list__title a').text.match(/submissions by (\d{1,2}\/\d{1,2}\/\d{4})/).to_s.strip
  document_description = item.at_css('.generic-list__title a')['href']

  # Format the closing date to a standard format
  on_notice_to = Date.strptime(on_notice_to.gsub("submissions by", "").strip, "%d/%m/%Y").to_s

  # Step 6: Ensure the entry does not already exist before inserting
  existing_entry = db.execute("SELECT * FROM kentish WHERE council_reference = ?", council_reference )

  if existing_entry.empty? # Only insert if the entry doesn't already exist
  # Step 5: Insert the data into the database
  db.execute("INSERT INTO kentish (address, council_reference, on_notice_to, description, document_description, date_scraped)
              VALUES (?, ?, ?, ?, ?, ?)", [address, council_reference, on_notice_to, description, document_description, date_scraped])

  logger.info("Data for #{council_reference} saved to database.")
    else
      logger.info("Duplicate entry for application #{council_reference} found. Skipping insertion.")
    end

end
