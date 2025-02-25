require 'nokogiri'
require 'open-uri'
require 'sqlite3'
require 'logger'
require 'date'
require 'cgi'
require 'selenium-webdriver'

# Configure Selenium to use a headless browser
options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--headless') # Run in headless mode (without UI)
options.add_argument('--disable-gpu')
options.add_argument('--no-sandbox')

# Open the page using Selenium WebDriver
driver = Selenium::WebDriver.for :chrome, options: options
driver.get('https://www.kentish.tas.gov.au/services/building-and-planning-services/planningapp')

# Give the page some time to load content (optional)
sleep 2

# Parse the page source using Nokogiri
doc = Nokogiri::HTML(driver.page_source)

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
