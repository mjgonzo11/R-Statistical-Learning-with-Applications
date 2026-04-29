# Clear workspace
rm(list = ls())

# Portable data loading

BUILD_FROM_RAW <- FALSE

data_dir <- "Data"
fp <- function(x) file.path(data_dir, x)

if (!BUILD_FROM_RAW) {
  df <- read.csv("latino_completion_final.csv")
  
  if (!("sat_missing" %in% names(df)) && "sat_median" %in% names(df)) {
    df$sat_missing <- as.integer(is.na(df$sat_median))
  }
  if (!("admission_missing" %in% names(df)) && "admission_rate" %in% names(df)) {
    df$admission_missing <- as.integer(is.na(df$admission_rate))
  }
}

# Import data

# The import will consist of importing data from 6 different datasets. 
# these datasets all come from the Integrated Postsecondary Education Data system
# or IPEDS which is provided by nces.ed.gov

if (BUILD_FROM_RAW) {
  gr  <- read.csv(fp("gr2024.csv"))

  #head(gr)

  ## GR: Build target Latino completion rate

  # Convert columns to correct types
  gr$GRHISPT = as.numeric(gr$GRHISPT)
  gr$LINE = as.character(gr$LINE)

  # Hispanic cohort LINE 10
  cohort = aggregate(GRHISPT ~ UNITID,
                      data = gr[gr$LINE == "10", ],
                      sum,
                      na.rm = TRUE)
  colnames(cohort)[2] = "hispanic_cohort"

  # Hispanic completions LINE 29A
  completed = aggregate(GRHISPT ~ UNITID,
                         data = gr[gr$LINE == "29A", ],
                         sum,
                         na.rm = TRUE)
  colnames(completed)[2] = "hispanic_completed_6yr"

  # Merge cohort + completed 
  # inner join: keep only UNITIDs with both
  target = merge(cohort, completed, by = "UNITID")

  # Compute Latino completion rate, in percent
  target$latino_completion_rate =
    (target$hispanic_completed_6yr /
       target$hispanic_cohort) * 100

  # Clean remove tiny cohorts, noisy rates
  # keep completion rate inside 0, 100
  target = target[target$hispanic_cohort >= 15, ]
  target = target[target$latino_completion_rate >= 0 &
                     target$latino_completion_rate <= 100, ]

  # Keep only what need, UNITID + target
  target = target[, c("UNITID", "latino_completion_rate")]
  dim(target)

  # graduation rates are reported in long format. For the 2024 GR file, Hispanic 
  # cohort size is identified by LINE ‘10’ and 150% completion by LINE ‘29A’. 
  # computed completion rates directly from race-specific counts.

  ## Institutional characteristics
  ic  <- read.csv(fp("ic2024.csv"))

  # Keep 4-Year Institutions

  # LEVEL1 == 1 means 4-year institutions, for project scope
  # CNTLAFFI = control type, public/private/etc
  ic_clean = ic[ic$LEVEL1 == 1,
               c("UNITID", "CNTLAFFI", "LEVEL1")]
  # Merge target with IC
  df = merge(target, ic_clean, by = "UNITID", all.x = TRUE)

  # Keep only 4-year and non-missing target
  df = df[df$LEVEL1 == 1, ]
  df = df[!is.na(df$latino_completion_rate), ]

  # Drop LEVEL1 column because it is a constant now
  df$LEVEL1 = NULL

  # From Dictionary of variables we know
  # 1 Public
  # 2 Private for-profit
  # 3 Private not-for-profit (no religious affiliation)
  # 4 Private not-for-profit (religious affiliation

  ## Retention + Student-Faculty Ratio
  ret <- read.csv(fp("ef2024d.csv"))
  
  # Keep only needed columns
  ret = ret[, c("UNITID", "RET_PCF", "STUFACR")]
  
  # Replace missing codes with NA
  ret$RET_PCF[ret$RET_PCF %in% c(-1, -2, -3)] = NA
  ret$STUFACR[ret$STUFACR %in% c(-1, -2, -3)] = NA
  
  # Convert to numeric
  ret$RET_PCF = as.numeric(ret$RET_PCF)
  ret$STUFACR = as.numeric(ret$STUFACR)
  
  # Rename columns
  colnames(ret) = c("UNITID",
                     "retention_rate",
                     "student_faculty_ratio")

  # Clean unrealistic ranges
  ret$retention_rate[ret$retention_rate < 0 |
                       ret$retention_rate > 100] = NA
  
  ret$student_faculty_ratio[
    ret$student_faculty_ratio < 1 |
      ret$student_faculty_ratio > 200] = NA

  # Merge into df
  df = merge(df, ret, by = "UNITID", all.x = TRUE)

  ## Pell %, Loan %, Loan Amount
  sfa <- read.csv(fp("sfa2324.csv"))
  
  # Keep only needed columns
  sfa = sfa[, c("UNITID", "PGRNT_P", "LOAN_P", "LOAN_A")]
  
  # Replace IPEDS missing codes (-1/-2/-3) with NA
  sfa[sfa %in% c(-1, -2, -3)] <- NA
  
  # Convert to numeric
  sfa$PGRNT_P = as.numeric(sfa$PGRNT_P)
  sfa$LOAN_P  = as.numeric(sfa$LOAN_P)
  sfa$LOAN_A  = as.numeric(sfa$LOAN_A)
  
  # Rename to clean names 
  colnames(sfa) <- c("UNITID",
                     "pct_pell",
                     "pct_loan",
                     "avg_loan_amt")

  # Merge
  df = merge(df, sfa, by = "UNITID", all.x = TRUE)

  ## Add institution name and State
  hd  <- read.csv(fp("hd2024.csv"))
  
  # Keep only what we need 
  hd_clean = hd[, c("UNITID", "INSTNM", "STABBR")]
  
  # merge
  df = merge(df, hd_clean, by = "UNITID", all.x = TRUE)

  ## Admissions: Admission Rate + SAT Median
  adm <- read.csv(fp("adm2024.csv"))
  
  # keep only what we need 
  adm = adm[, c("UNITID", "APPLCN", "ADMSSN", "SATVR50", "SATMT50")]
  
  # Replace missing codes with NA
  adm[adm %in% c(-1, -2, -3)] <- NA
  
  # Convert to numeric
  adm$APPLCN  = as.numeric(adm$APPLCN)
  adm$ADMSSN  = as.numeric(adm$ADMSSN)
  adm$SATVR50 = as.numeric(adm$SATVR50)
  adm$SATMT50 = as.numeric(adm$SATMT50)

  # Admission rate = admitted / applicants 
  # values must be between 0 and 1 
  adm$admission_rate = adm$ADMSSN / adm$APPLCN
  adm$admission_rate[adm$admission_rate < 0 |
                       adm$admission_rate > 1] <- NA
  
  # SAT composite median = average of SATVR50 and SATMT50
  adm$sat_median = rowMeans(
    cbind(adm$SATVR50, adm$SATMT50), na.rm = TRUE
    )
  # rowMeans with na.rm=TRUE can create NaN when BOTH are missing
  # convert NaN to NA
  adm$sat_median[is.nan(adm$sat_median)] <- NA
  
  adm_final = adm[, c("UNITID",
                       "admission_rate",
                       "sat_median")]
  # merge
  df = merge(df, adm_final, by = "UNITID", all.x = TRUE)

  # Missing indicators will be added 
  # Some schools do not report SAT/admissions, open-admission
  # this in itself is informative
  df$sat_missing <- 0L
  df$sat_missing[is.na(df$sat_median)] <- 1L
  
  df$admission_missing <- 0L
  df$admission_missing[is.na(df$admission_rate)] <- 1L

  # 1 originally missing
  # 0 originally observed (not missing)
  
  #inputting median values
  #so we can model without dropping rows
  
  sat_med = median(df$sat_median, na.rm = TRUE)
  df$sat_median[is.na(df$sat_median)] <- sat_med
  
  adm_med = median(df$admission_rate, na.rm = TRUE)
  df$admission_rate[is.na(df$admission_rate)] <- adm_med
  
  ret_med = median(df$retention_rate, na.rm = TRUE)
  df$retention_rate[is.na(df$retention_rate)] <- ret_med
  
  loan_med = median(df$avg_loan_amt, na.rm = TRUE)
  df$avg_loan_amt[is.na(df$avg_loan_amt)] <- loan_med
  
  #cat("Total missing cells in df:\n")
  #print(sum(is.na(df)))
  
  #write.csv(df, "latino_completion_final.csv", row.names = FALSE)
  #getwd()
}

# Feature dictionary
feature_table <- data.frame(
  Feature = c(
    "latino_completion_rate",
    "retention_rate",
    "student_faculty_ratio",
    "pct_pell",
    "pct_loan",
    "avg_loan_amt",
    "admission_rate",
    "sat_median",
    "sat_missing",
    "admission_missing",
    "CNTLAFFI"
  ),
  Description = c(
    "Six-year completion rate for Hispanic students (%)",
    "First-year retention rate (%)",
    "Number of students per faculty member",
    "Percent of students receiving Pell Grants",
    "Percent of students receiving loans",
    "Average student loan amount (USD)",
    "Admissions rate (admitted/applicants)",
    "Median SAT score (average of math and verbal)",
    "Indicator for missing SAT data (1 = missing)",
    "Indicator for missing admission data (1 = missing)",
    "Institution type (public/private categories)"
  )
)

feature_table
# write.csv(feature_table, "feature_description_table.csv", row.names = FALSE)

#######
# EDA #
#######

summary(df$latino_completion_rate)

numeric_df = df[, sapply(df, is.numeric)]
corr_matrix = cor(numeric_df, use = "pairwise.complete.obs")
corr_matrix

sort(corr_matrix[, "latino_completion_rate"], decreasing = TRUE)

pairs(numeric_df)

# Histogram
hist(df$latino_completion_rate,
     col = "lightgreen",
     border = "black",
     breaks = 25,
     main = "Distribution of Latino Completion",
     xlab = "Latino Completion Rate")

# Scatter Plots
# Retention vs Completion
plot(df$retention_rate,
     df$latino_completion_rate,
     main = "Retention vs Completion",
     xlab = "Retention Rate",
     ylab = "Completion Rate")

# Avg Loan Amount vs Completion 
plot(df$avg_loan_amt,
     df$latino_completion_rate,
     main = "Avg Loan Amount vs Completion",
     xlab = "Average Loan Amount",
     ylab = "Completion Rate")

# Loan % vs Completion
plot(df$pct_loan,
     df$latino_completion_rate,
     main = "Loan % vs Completion",
     xlab = "Loan %",
     ylab = "Completion Rate")

# SAT vs Completion
plot(df$sat_median,
     df$latino_completion_rate,
     main = "SAT vs Completion",
     xlab = "SAT Median",
     ylab = "Completion Rate")

# Admission Rate vs Completion
plot(df$admission_rate,
     df$latino_completion_rate,
     main = "Admission Rate vs Completion",
     xlab = "Admission Rate",
     ylab = "Completion Rate")

# Final modeling data
df_model = df[, c("latino_completion_rate",
                  "retention_rate",
                  "student_faculty_ratio",
                  "pct_pell",
                  "pct_loan",
                  "avg_loan_amt",
                  "admission_rate",
                  "sat_median",
                  "sat_missing",
                  "admission_missing",
                  "CNTLAFFI")]

# Handle missing CNTLAFFI without dropping rows
df_model$CNTLAFFI <- as.character(df_model$CNTLAFFI)
df_model$CNTLAFFI[is.na(df_model$CNTLAFFI)] <- "Unknown"
df_model$CNTLAFFI <- as.factor(df_model$CNTLAFFI)

# Train/test split
set.seed(1)
train <- sample(1:nrow(df_model), size = 0.7 * nrow(df_model))
test  <- setdiff(1:nrow(df_model), train)

# Add missing indicators
extra_missing_vars <- c("retention_rate","student_faculty_ratio","pct_pell","pct_loan","avg_loan_amt")
for (v in extra_missing_vars) {
  df_model[[paste0(v, "_missing")]] <- as.integer(is.na(df_model[[v]]))
}

# Train-only median imputation
num_vars <- c("retention_rate","student_faculty_ratio","pct_pell","pct_loan","avg_loan_amt",
              "admission_rate","sat_median")
for (v in num_vars) {
  med <- median(df_model[[v]][train], na.rm = TRUE)
  df_model[[v]][train][is.na(df_model[[v]][train])] <- med
  df_model[[v]][test][is.na(df_model[[v]][test])] <- med
}

# Build x/y
x <- model.matrix(latino_completion_rate ~ ., df_model)[,-1]
y <- df_model$latino_completion_rate
y.test <- y[test]

#####################
# LINEAR REGRESSION #
#####################

lm.fit = lm(latino_completion_rate ~ .,
            data = df_model,
            subset = train)

# Linear regression diagnostics (residuals, QQ, leverage)
par(mfrow = c(2,2))
plot(lm.fit)
par(mfrow = c(1,1))

summary(lm.fit)
summary(lm.fit)$coefficients

lm.pred = predict(lm.fit, newdata = df_model[test, ])

# Test MSE
mse.lm = mean((lm.pred - y.test)^2)
mse.lm

# Test RMSE
rmse.lm = sqrt(mse.lm)
rmse.lm

# Test R^2
ss_res = sum((y.test - lm.pred)^2)
ss_tot = sum((y.test - mean(y.test))^2)
r2.lm = 1 - ss_res / ss_tot
r2.lm

plot(lm.pred, y.test,
     main = "Linear Model: Predicted vs Actual",
     xlab = "Predicted",
     ylab = "Actual")
abline(0,1)

###############
# ELASTIC NET #
###############

library(glmnet)

# For glmnet we need x and y

# Try alpha = 0.5 balanced Ridge + Lasso
set.seed(1)
cv.enet = cv.glmnet(x[train, ], y[train],
                    alpha = 0.5)

# Plot CV results
plot(cv.enet,
     main = "Elastic Net CV (alpha = 0.5)\n")

# Best lambda
bestlam.enet = cv.enet$lambda.min
bestlam.enet

# Fit final model
enet.mod = glmnet(x[train, ], y[train],
                  alpha = 0.5)

# Predict on test set
enet.pred = as.numeric(predict(enet.mod, s = bestlam.enet, newx = x[test, ]))

# Test MSE
mse.enet = mean((enet.pred - y.test)^2)
mse.enet

# Test RMSE
rmse.enet = sqrt(mse.enet)
rmse.enet

# Test R^2
ss_res = sum((y.test - enet.pred)^2)
ss_tot = sum((y.test - mean(y.test))^2)
r2.enet = 1 - ss_res / ss_tot
r2.enet

# Coefficients
enet.coef <- coef(cv.enet, s = "lambda.min")
enet.coef

# Try alpha = 0.1 Ridge inclined
# Lower alpha makes model more ridge-like, so coefficients are shrunk
# more smoothly and fewer predictors are forced exactly to zero
set.seed(1)
cv.enet2 = cv.glmnet(x[train, ], y[train],
                    alpha = 0.1)

# Plot CV results
plot(cv.enet2,
     main = "Elastic Net CV (alpha = 0.1)\n")

# Best lambda
bestlam.enet2 = cv.enet2$lambda.min
bestlam.enet2

# Fit final model
enet.mod2 = glmnet(x[train, ], y[train],
                  alpha = 0.1)

# Predict on test set
enet.pred2 = as.numeric(predict(enet.mod2, s = bestlam.enet2, newx = x[test, ]))

# Test MSE
mse.enet2 = mean((enet.pred2 - y.test)^2)
mse.enet2

# Test RMSE
rmse.enet2 = sqrt(mse.enet2)
rmse.enet2

# Test R^2
ss_res2 = sum((y.test - enet.pred2)^2)
ss_tot2 = sum((y.test - mean(y.test))^2)
r2.enet2 = 1 - ss_res2 / ss_tot2
r2.enet2

# Coefficients
enet.coef2 <- coef(cv.enet2, s = "lambda.min")
enet.coef2

# Elastic net Model Comparison
data.frame(
  Model = c("Elastic Net alpha=0.5", "Elastic Net alpha=0.1"),
  MSE = c(mse.enet, mse.enet2),
  RMSE = c(rmse.enet, rmse.enet2),
  R2 = c(r2.enet, r2.enet2)
)
  # results indicate having alpha = 0.1, slightly improved model
  # will proceed with comparisons with Elastic Net 2

plot(enet.pred2, y.test,
     main = "Elastic Net (alpha = 0.1): Predicted vs Actual",
     xlab = "Predicted",
     ylab = "Actual")
abline(0, 1)

#################
# RANDOM FOREST #
#################

library(randomForest)

set.seed(1)
rf.model = randomForest(latino_completion_rate ~ .,
                        data = df_model,
                        subset = train,
                        ntree = 500,
                        importance = T)

# Print model
print(rf.model)

# Predict on test set
rf.pred = predict(rf.model, newdata = df_model[test, ])

# Test MSE
mse.rf = mean((rf.pred - y.test)^2)
mse.rf

# Test RMSE
rmse.rf = sqrt(mse.rf)
rmse.rf

# Test R^2
ss_res = sum((y.test - rf.pred)^2)
ss_tot = sum((y.test - mean(y.test))^2)
r2.rf = 1 - ss_res / ss_tot
r2.rf

# Variable importance
importance(rf.model)
# Plot variable importance
varImpPlot(rf.model,
           main = "Random Forest: Variable Importance")

plot(rf.pred, y.test,
     main = "Random Forest: Predicted vs Actual",
     xlab = "Predicted",
     ylab = "Actual")
abline(0, 1)

###########
# BAGGING #
###########
# (mtry = p)

p <- ncol(df_model) - 1  # number of predictors

set.seed(1)
bag.model <- randomForest(latino_completion_rate ~ .,
                          data = df_model,
                          subset = train,
                          mtry = p,
                          ntree = 500,
                          importance = TRUE)

# Print model
print(bag.model)

# Predict on test set
bag.pred <- predict(bag.model, newdata = df_model[test, ])

# Test MSE
mse.bag <- mean((bag.pred - y.test)^2)
mse.bag

# Test RMSE
rmse.bag <- sqrt(mse.bag)
rmse.bag

# Test R^2
ss_res <- sum((y.test - bag.pred)^2)
ss_tot <- sum((y.test - mean(y.test))^2)
r2.bag <- 1 - ss_res / ss_tot
r2.bag

# Variable importance
importance(bag.model)
# Importance plot
varImpPlot(bag.model,
           main = "Bagging: Variable Importance")

plot(bag.pred, y.test,
     main = "Bagging: Predicted vs Actual",
     xlab = "Predicted",
     ylab = "Actual")
abline(0, 1)

############
# BOOSTING #
############

# boosting model (GBM) with CV

library(gbm)

set.seed(1)
boost.model <- gbm(latino_completion_rate ~ .,
                   data = df_model[train, ],
                   distribution = "gaussian",
                   n.trees = 5000,
                   interaction.depth = 2,
                   shrinkage = 0.01,
                   cv.folds = 10,
                   verbose = FALSE)

best_iter <- gbm.perf(boost.model, method = "cv")

# Print model
print(boost.model)

# Predict on test set
boost.pred <- predict(boost.model,
                      newdata = df_model[test, ],
                      n.trees = best_iter)

# Test MSE
mse.boost <- mean((boost.pred - y.test)^2)
mse.boost

# Test RMSE
rmse.boost <- sqrt(mse.boost)
rmse.boost

# Test R^2
ss_res <- sum((y.test - boost.pred)^2)
ss_tot <- sum((y.test - mean(y.test))^2)
r2.boost <- 1 - ss_res / ss_tot
r2.boost

# Variable influence
par(mar = c(5, 10, 4, 2))
summary(boost.model,
        main = "Boosting (GBM): Variable Importance",
        las = 2,
        cBars = 10) # exclude the rel. inf that are 0

par(mar = c(5, 4, 4, 2))
plot(boost.pred, y.test,
     main = "Boosting (GBM): Predicted vs Actual",
     xlab = "Predicted",
     ylab = "Actual")
abline(0, 1)

##############
# COMPARISON #
##############

results <- data.frame(
  Model = c("Linear", "Elastic Net", "Random Forest", "Bagging", "Boosting"),
  Test_MSE = c(mse.lm, mse.enet2, mse.rf, mse.bag, mse.boost),
  Test_RMSE = c(rmse.lm, rmse.enet2, rmse.rf, rmse.bag, rmse.boost),
  Test_R2 = c(r2.lm, r2.enet2, r2.rf, r2.bag, r2.boost)
)

results
results[order(results$Test_RMSE), ]  # sorts best RMSE at the top

# t-test, to check if difference in RMSE is statistically significant
# squared errors per test observation and per model
err.lm    = (lm.pred    - y.test)^2
err.enet2 = (enet.pred2 - y.test)^2
err.rf    = (rf.pred    - y.test)^2
err.bag   = (bag.pred   - y.test)^2
err.boost = (boost.pred - y.test)^2

# paired tests — RF vs each other model
tt.lm    = t.test(err.rf, err.lm,    paired = TRUE)
tt.enet2 = t.test(err.rf, err.enet2, paired = TRUE)
tt.bag   = t.test(err.rf, err.bag,   paired = TRUE)
tt.boost = t.test(err.rf, err.boost, paired = TRUE)

# summary table
pairwise_results <- data.frame(
  Comparison = c("RF vs Linear", "RF vs Elastic Net", 
                 "RF vs Bagging", "RF vs Boosting"),
  Mean_Diff_in_SqErr = c(mean(err.rf - err.lm),  mean(err.rf - err.enet2),
                         mean(err.rf - err.bag), mean(err.rf - err.boost)),
  p_value = c(tt.lm$p.value, tt.enet2$p.value, 
              tt.bag$p.value, tt.boost$p.value)
)

print(pairwise_results)

# Random Forest - best performing
# difference between linear models and RF are significant

# Partial dependence plots
# retention rates
partialPlot(rf.model, pred.data = df_model[train, ], x.var = "retention_rate",
            main = "RF Partial Dependence: Retention Rate",
            xlab = "Retention Rate", ylab = "Latino Completion Rate")

# institution type
partialPlot(rf.model, pred.data = df_model[train, ], x.var = "CNTLAFFI",
            main = "RF Partial Dependence: Institution Type",
            xlab = "Instituition Type", ylab = "Latino Completion Rate")

# loan %
partialPlot(rf.model, pred.data = df_model[train, ], x.var = "pct_loan",
            main = "RF Partial Dependence: % Loans",
            xlab = "% Receiving Loans", ylab = "Latino Completion Rate")

# pell grant %
partialPlot(rf.model, pred.data = df_model[train, ], x.var = "pct_pell",
            main = "RF Partial Dependence: % Pell",
            xlab = "% Receiving Pell", ylab = "Latino Completion Rate")

# sat median
partialPlot(rf.model, pred.data = df_model[train, ], x.var = "sat_median",
            main = "RF Partial Dependence: SAT Median",
            xlab = "SAT Median", ylab = "Latino Completion Rate")
