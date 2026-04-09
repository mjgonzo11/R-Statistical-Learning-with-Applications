# Clear workspace
rm(list = ls())

#Import data

#The import will consist of importing data from 6 different datasets. 
#these datasets all come from the Integrated Postsecondary Education Data system
#or IPEDS which is provided by nces.ed.gov

gr = read.csv(
  "C:\\Users\\mjgon\\OneDrive\\Desktop\\Stats R Project\\Data\\gr2024.csv"
  )

#head(gr)

# GR: Build target Latino completion rate

#Convert columns to correct types
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

#Compute Latino completion rate, in percent
target$latino_completion_rate =
  (target$hispanic_completed_6yr /
     target$hispanic_cohort) * 100

# Clean remove tiny cohorts, noisy rates
# keep completion rate inside 0, 100
target = target[target$hispanic_cohort >= 15, ]
target = target[target$latino_completion_rate >= 0 &
                   target$latino_completion_rate <= 100, ]

#Keep only what need, UNITID + target
target = target[, c("UNITID", "latino_completion_rate")]

dim(target)

#graduation rates are reported in long format. For the 2024 GR file, Hispanic 
#cohort size is identified by LINE ‘10’ and 150% completion by LINE ‘29A’. 
#I computed completion rates directly from race-specific counts.

ic = read.csv(
  "C:\\Users\\mjgon\\OneDrive\\Desktop\\Stats R Project\\Data\\ic2024.csv"
  )

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

#From Dictionary of variables we know
#1 Public
#2 Private for-profit
#3 Private not-for-profit (no religious affiliation)
#4 Private not-for-profit (religious affiliation

#Retention + Student-Faculty Ratio

ret = read.csv(
  "C:\\Users\\mjgon\\OneDrive\\Desktop\\Stats R Project\\Data\\ef2024d.csv"
  )

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
    ret$student_faculty_ratio > 200
] = NA

# Merge into df
df = merge(df, ret, by = "UNITID", all.x = TRUE)

#Pell %, Loan %, Loan Amount

sfa = read.csv(
  "C:\\Users\\mjgon\\OneDrive\\Desktop\\Stats R Project\\Data\\sfa2324.csv"
  )

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

#Add institution name and State

hd = read.csv(
  "C:\\Users\\mjgon\\OneDrive\\Desktop\\Stats R Project\\Data\\hd2024.csv"
  )

# Keep only what we need 
hd_clean = hd[, c("UNITID", "INSTNM", "STABBR")]

# merge
df = merge(df, hd_clean, by = "UNITID", all.x = TRUE)

#Admissions: Admission Rate + SAT Median

adm = read.csv(
  "C:\\Users\\mjgon\\OneDrive\\Desktop\\Stats R Project\\Data\\adm2024.csv"
  )

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

#1 originally missing
#0 originally observed (not missing)

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

#write.csv(feature_table, "feature_description_table.csv", row.names = FALSE)

# EDA 

summary(df$latino_completion_rate)


numeric_df = df[, sapply(df, is.numeric)]

corr_matrix = cor(numeric_df,
                   use = "pairwise.complete.obs")
corr_matrix

sort(corr_matrix[, "latino_completion_rate"], decreasing = TRUE)

pairs(numeric_df)

hist(df$latino_completion_rate,
     col = "lightgreen",
     border = "black",
     breaks = 25,
     main = "Distribution of Latino Completion",
     xlab = "Latino Completion Rate")

plot(df$retention_rate,
     df$latino_completion_rate,
     main = "Retention vs Completion",
     xlab = "Retention Rate",
     ylab = "Completion Rate")

plot(df$sat_median,
     df$latino_completion_rate,
     main = "SAT vs Completion",
     xlab = "SAT Median",
     ylab = "Completion Rate")

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

df_model = na.omit(df_model)
# convert categorical value
df_model$CNTLAFFI = as.factor(df_model$CNTLAFFI)

# train test split
set.seed(1)
train = sample(1:nrow(df_model), 0.7 * nrow(df_model))
test = (-train)

x = model.matrix(latino_completion_rate ~ ., df_model)[,-1]
y = df_model$latino_completion_rate
y.test = y[test]

# Base model
lm.fit = lm(latino_completion_rate ~ .,
            data = df_model,
            subset = train)

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

# ELASTIC NET

library(glmnet)

# For glmnet we need x and y

# Choose a grid of lambda values
grid = 10^seq(10, -2, length = 100)

# Try alpha = 0.5 balanced Ridge + Lasso
set.seed(1)
cv.enet = cv.glmnet(x[train, ], y[train],
                    alpha = 0.5)

# Plot CV results
plot(cv.enet)

# Best lambda
bestlam.enet = cv.enet$lambda.min
bestlam.enet

# Fit final model
enet.mod = glmnet(x[train, ], y[train],
                  alpha = 0.5)

# Predict on test set
enet.pred = predict(enet.mod,
                    s = bestlam.enet,
                    newx = x[test, ])

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
out = glmnet(x, y, alpha = 0.5, lambda = grid)
enet.coef = predict(out, type = "coefficients", s = bestlam.enet)
enet.coef

# RANDOM FOREST

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
# Numeric importance table
importance(rf.model)
# Plot variable importance
varImpPlot(rf.model)

results = data.frame(
  Model = c("Linear", "Random Forest", "Elastic Net"),
  Test_MSE = c(mse.lm, mse.rf, mse.enet),
  Test_RMSE = c(rmse.lm, rmse.rf, rmse.enet),
  Test_R2 = c(r2.lm, r2.rf, r2.enet)
)

results

