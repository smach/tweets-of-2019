library(rtweet)

start_2019 <- strptime("2019-01-01 00:00:00", "%F %T", tz = "UTC")
end_2019 <- strptime("2020-01-01 00:00:00", "%F %T", tz = "UTC")

check_rate_limit <- function(query = "statuses/user_timeline") {
  now <- Sys.time()
  if (!exists(".rate_limit")) {
    .rate_limit <<- list(remaining = 900, reset_at = now + 15 * 60, checked = now)
  }
  if (.rate_limit$checked < (now - 60) || .rate_limit$reset_at < now) {
    rl <- rtweet::rate_limits(query = "statuses/user_timeline")
    .rate_limit <<- list(remaining = rl$remaining, reset_at = rl$reset_at, checked = now)
  }
  return(.rate_limit)
}

get_timeline <- purrr::safely(rtweet::get_timeline)

get_user_tweets <- function(screen_name, ...) {
  get_timeline(
    screen_name,
    include_rts = FALSE,
    exclude_replies = FALSE,
    n = 3200
  )
}

sum_ <- function(x) {
  if (any(!is.na(x))) {
    sum(x, na.rm = TRUE)
  }
}

best <- function(x, by = "favorite") {
  by <- paste0(by, "_count")
  x <- x[!x$is_retweet, ]
  x <- x[x[[by]] == max(x[[by]], na.rm = TRUE), ]
  x[1, ]
}
hashtags <- function(x) {
  x <- unlist(x)
  if(!length(x)) return(list(hashtag = NULL, count = NULL))
  x <- table(x)
  x <- sort(x, decreasing = TRUE)[seq(1, min(length(x), 10))]
  lapply(names(x), function(h) list(hashtag = h, count = x[[h]]))
}
mentions <- function(x) {
  x <- unlist(x)
  if(!length(x)) return(list(mentions = NULL, count = NULL))
  x <- table(x)
  x <- sort(x, decreasing = TRUE)[seq(1, min(length(x), 10))]
  lapply(names(x), function(s) list(screen_name = s, count = x[[s]]))
}
user_info <- function(tw) {
  u <- rtweet::users_data(tw[1, ])
  as.list(u)
}
tweet_stats <- function(tw) {
  tw_2019 <- tw[tw$created_at >= start_2019 & tw$created_at < end_2019, ]
  tw_best_favorite <- best(tw_2019, "favorite")
  tw_best_retweet <- best(tw_2019, "retweet")
  list(
    user = user_info(tw),
    has_tweet_prior_2019 = any(tw$created_at < start_2019),
    created_at_min = min(tw_2019$created_at),
    created_at_max = max(tw_2019$created_at),
    n = nrow(tw_2019[!tw_2019$is_retweet, ]),
    favorite_count = sum_(tw_2019$favorite_count),
    retweet_count = sum_(tw_2019$retweet_count),
    quote_count = sum_(tw_2019$quote_count),
    reply_count = sum_(tw_2019$reply_count),
    best_favorite = list(
      status_id = tw_best_favorite$status_id,
      url = tw_best_favorite$status_url,
      favorite_count = tw_best_favorite$favorite_count,
      retweet_count = tw_best_favorite$retweet_count
    ),
    best_retweet = list(
      status_id = tw_best_retweet$status_id,
      url = tw_best_retweet$status_url,
      favorite_count = tw_best_retweet$favorite_count,
      retweet_count = tw_best_retweet$retweet_count
    ),
    hashtags = hashtags(tw_2019$hashtags),
    mentions = mentions(tw_2019$mentions_screen_name)
  )
}
