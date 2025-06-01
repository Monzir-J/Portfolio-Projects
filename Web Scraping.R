library(rvest)
library(stringr)

url <- 'http://books.toscrape.com/catalogue/category/books/travel_2/index.html'

titles <- read_html(url) %>% 
  html_nodes('h3') %>%
  html_nodes('a') %>% 
  html_text()

urls <- read_html(url) %>%
  html_nodes('.image_container') %>% 
  html_nodes('a') %>% 
  html_attr('href') %>% 
  str_replace_all('../../../', '/')

imgs <- read_html(url) %>% 
  html_nodes('.image_container') %>%
  html_nodes('img') %>%
  html_attr('src') %>%
  str_replace_all('../../../../', '/')

ratings <- read_html(url) %>% 
  html_nodes('p.star-rating') %>% 
  html_attr('class') %>% 
  str_replace_all('star-rating ', '')

prices <- read_html(url) %>% 
  html_nodes('.product_price') %>% 
  html_nodes('.price_color') %>% 
  html_text()

availability <- read_html(url) %>% 
  html_nodes('.product_price') %>% 
  html_nodes('.instock') %>% 
  html_text() %>% 
  str_trim()

scraped <- data.frame(
  Title = titles, 
  URL = urls, 
  SourceImage = imgs, 
  Rating = ratings, 
  Price = prices, 
  Availability = availability
)
