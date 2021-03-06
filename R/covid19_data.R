# Updated on June 05, 2020
# if(!require(testthat)) install.packages("testthat", repos = "	http://testthat.r-lib.org, https://github.com/r-lib/testthat")
# if(!require(tidyverse)) install.packages("tidyverse", repos = "http://cran.us.r-project.org")
# if(!require(data.table)) install.packages("data.table", repos = "http://cran.us.r-project.org")
library(tidyverse)
library(data.table)
library(magrittr)
library(lubridate)
library(gridExtra)
library(kableExtra)
library(plotly)
library(DT)

# Pulling raw cofirmeddata from JHUCSSE
conf_url <- "https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_confirmed_global.csv"
raw_conf <- read.csv(file = conf_url,
                     stringsAsFactors = FALSE)
# Pulling raw death data from JHUCSEE

death_url <- "https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_deaths_global.csv"
raw_death <- read.csv(file =death_url,
                      stringsAsFactors = FALSE,
                      fill =FALSE)

# Pulling raw recovered data from JHUCSEE
rec_url <- "https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_recovered_global.csv"
raw_rec <- read.csv(file =rec_url,
                    stringsAsFactors = FALSE,
                    fill =FALSE)

###########################################################################################
lapply(1:ncol(raw_conf), function(i){
  if(all(is.na(raw_conf[, i]))){
    raw_conf <<- raw_conf[, -i]
  } else {
    return(NULL)
  }
})

# Transforming the data from wide to long
# Creating new data frame
df_conf <- raw_conf[, 1:4]

for(i in 5:ncol(raw_conf)){

  raw_conf[,i] <- as.integer(raw_conf[,i])

  if(i == 5){
    df_conf[[names(raw_conf)[i]]] <- raw_conf[, i]
  } else {
    df_conf[[names(raw_conf)[i]]] <- raw_conf[, i] - raw_conf[, i - 1]
  }


}


df_conf1 <-  df_conf %>% tidyr::pivot_longer(cols = dplyr::starts_with("X"),
                                             names_to = "date_temp",
                                             values_to = "cases_temp")

# Parsing the date
df_conf1$month <- sub("X", "",
                      strsplit(df_conf1$date_temp, split = "\\.") %>%
                        purrr::map_chr(~.x[1]) )

df_conf1$day <- strsplit(df_conf1$date_temp, split = "\\.") %>%
  purrr::map_chr(~.x[2])


df_conf1$date <- as.Date(paste("2020", df_conf1$month, df_conf1$day, sep = "-"))

# Aggregate the data to daily
df_conf2 <- df_conf1 %>%
  dplyr::group_by(Province.State, Country.Region, Lat, Long, date) %>%
  dplyr::summarise(cases = sum(cases_temp)) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(type = "confirmed",
                Country.Region = trimws(Country.Region),
                Province.State = trimws(Province.State))

#################################################################################

lapply(1:ncol(raw_death), function(i){
  if(all(is.na(raw_death[, i]))){
    raw_death <<- raw_death[, -i]
  } else {
    return(NULL)
  }
})

# Transforming the data from wide to long
# Creating new data frame
df_death <- raw_death[, 1:4]

for(i in 5:ncol(raw_death)){
  raw_death[,i] <- as.integer(raw_death[,i])
  raw_death[,i] <- ifelse(is.na(raw_death[, i]), 0 , raw_death[, i])

  if(i == 5){
    df_death[[names(raw_death)[i]]] <- raw_death[, i]
  } else {
    df_death[[names(raw_death)[i]]] <- raw_death[, i] - raw_death[, i - 1]
  }
}


df_death1 <-  df_death %>% tidyr::pivot_longer(cols = dplyr::starts_with("X"),
                                               names_to = "date_temp",
                                               values_to = "cases_temp")

# Parsing the date
df_death1$month <- sub("X", "",
                       strsplit(df_death1$date_temp, split = "\\.") %>%
                         purrr::map_chr(~.x[1]) )

df_death1$day <- strsplit(df_death1$date_temp, split = "\\.") %>%
  purrr::map_chr(~.x[2])


df_death1$date <- as.Date(paste("2020", df_death1$month, df_death1$day, sep = "-"))

# Aggregate the data to daily
df_death2 <- df_death1 %>%
  dplyr::group_by(Province.State, Country.Region, Lat, Long, date) %>%
  dplyr::summarise(cases = sum(cases_temp)) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(type = "death",
                Country.Region = trimws(Country.Region),
                Province.State = trimws(Province.State))

#################################################################################

 lapply(1:ncol(raw_rec), function(i){
   if(all(is.na(raw_rec[, i]))){
     raw_rec <<- raw_rec[, -i]
   } else {
     return(NULL)
   }
 })
# Fixing US data
# Aggregating county level to state level

raw_us_rec <- raw_rec %>%
   dplyr::filter(Country.Region == "US") %>%
   dplyr::mutate(state = ifelse(!grepl(",", Province.State),
                                Province.State,
                                trimws(substr(Province.State,
                                              regexpr(",", Province.State) + 1,
                                              regexpr(",", Province.State) + 3)))) %>%
   dplyr::left_join(data.frame(state = state.abb,
                               state_name = state.name,
                               stringsAsFactors = FALSE),
                    by = "state") %>%
   dplyr::mutate(state_name = ifelse(is.na(state_name), state, state_name)) %>%
   dplyr::mutate(state_name = ifelse(state_name == "D.", "Washington, D.C.", state_name)) %>%
   dplyr::mutate(Province.State = state_name) %>%
   dplyr::select(-state, -state_name)

 raw_us_map <- raw_us_rec %>%
   dplyr::select("Province.State","Country.Region", "Lat", "Long") %>%
   dplyr::distinct() %>%
   dplyr::mutate(dup = duplicated(Province.State)) %>%
   dplyr::filter(dup == FALSE) %>%
   dplyr::select(-dup)

 us_agg_rec <- aggregate(x = raw_us_rec[, 5:(ncol(raw_us_rec))], by = list(raw_us_rec$Province.State), FUN = sum) %>%
   dplyr::select(Province.State = Group.1, dplyr::everything())

 us_fix_rec <- raw_us_map %>% dplyr::left_join(us_agg_rec, by = "Province.State")


 raw_rec1 <- raw_rec %>%
   dplyr::filter(Country.Region != "US") %>%
   dplyr::bind_rows(us_fix_rec)

# Transforming the data from wide to long
# Creating new data frame
 df_rec <- raw_rec1[, 1:4]
 for(i in 5:ncol(raw_rec1)){
 raw_rec1[,i] <- as.integer(raw_rec1[,i])
 raw_rec1[,i] <- ifelse(is.na(raw_rec1[, i]), 0 , raw_rec1[, i])

   if(i == 5){
     df_rec[[names(raw_rec1)[i]]] <- raw_rec1[, i]
   } else {
     df_rec[[names(raw_rec1)[i]]] <- raw_rec1[, i] - raw_rec1[, i - 1]
   }
 }


 df_rec1 <-  df_rec %>% tidyr::pivot_longer(cols = dplyr::starts_with("X"),
                                            names_to = "date_temp",
                                            values_to = "cases_temp")

# Parsing the date
 df_rec1$month <- sub("X", "",
                      strsplit(df_rec1$date_temp, split = "\\.") %>%
                        purrr::map_chr(~.x[1]) )

 df_rec1$day <- strsplit(df_rec1$date_temp, split = "\\.") %>%
   purrr::map_chr(~.x[2])


 df_rec1$date <- as.Date(paste("2020", df_rec1$month, df_rec1$day, sep = "-"))

# Aggregate the data to daily
 df_rec2 <- df_rec1 %>%
   dplyr::group_by(Province.State, Country.Region, Lat, Long, date) %>%
   dplyr::summarise(cases = sum(cases_temp)) %>%
   dplyr::ungroup() %>%
   dplyr::mutate(type = "recovered",
                 Country.Region = trimws(Country.Region),
                 Province.State = trimws(Province.State))

#################################################################################

covid19 <- dplyr::bind_rows(df_conf2, df_death2,df_rec2) %>%
  as.data.frame()
head(covid19)

