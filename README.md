# R-Statistical-Learning-with-Applications

## Intro
This project builds a predictive model to estimate Latino (Hispanic) six-year college completion rates using institution-level data from the Integrated Postsecondary Education Data System (IPEDS) 2024.

The analysis focuses exclusively on four-year U.S. institutions and integrates multiple IPEDS components to examine how institutional characteristics, financial context, academic selectivity, and retention influence Latino completion outcomes.

📂 Data Sources (IPEDS 2024)

All datasets were downloaded from NCES IPEDS:

* GR2024 – Graduation Rates (used to construct target variable)
* IC2024 – Institutional Characteristics
* EF2024D – Fall Enrollment (retention + student–faculty ratio)
* SFA2324 – Student Financial Aid
* HD2024 – Institutional directory (state, name)
* ADM2024 – Admissions (selectivity measures)

IPEDS Graduation Rates are reported in long format, each row represents a single observation, with variables listed in columns
For this project we wil focus on Hispanic students:
* LINE = "10" → Hispanic cohort size
* LINE = "29A" → Hispanic completions within 150% time

## Target Variable Construction
The Latino completion rate was calculated as:
Completion Rate = 
Hispanic 6-year Completions /
Hispanic Cohort Size * 100

Filtering applied:
Cohort size ≥ 15 students
Completion rate between 0 and 100
Only four-year institutions retained
Final modeling dataset includes approximately 2,000 institutions.

## Key predictor Values
As mentioned, the data examined three main types of values
* Academic Structure
  * Retention rate (first-year persistence)
  * Student–faculty ratio
  * Admission rate (admitted / applicants)
  * SAT median score (average of SATVR50 & SATMT50)

* Financial Context
  * Percent receiving Pell Grants
  * Percent receiving loans
  * Average loan amount

* Institution type
  * Public
  * Private for profit
  * private for profit relgious

## Data Cleaning and pre processing
IPEDS missing codes (-1, -2, -3) converted to NA

Median imputation applied to
* SAT median
* Admission Rate
* Retention rate
* Average loan amount

Missing indicator values created for sat_missing and admission_missing
this allows model to distiguish between Schools with avg selectivity and that did not report selectivity metrics

## Exploratory Data Analysis (EDA)
Pre-model analysis revealed:
* Strong positive relationship between retention and completion
* Positive relationship between SAT median and completion
* Negative relationship between admission rate and completion
* Moderate financial effects
* Modest geographic (state-level) influence

## Models Used

Multiple models were implemented and compared:

📈 Linear Models
* Linear Regression (baseline)
* Ridge Regression
* Lasso Regression
* Elastic Net
🌲 Tree-Based Models
* Decision Tree
* Random Forest
* Boosting

## 📊 Model Performance
Model	R²	RMSE
Linear Regression (baseline)	~0.49	~13.45
Extended Linear Model	~0.54	~12.80
Elastic Net	~0.54	~12.85
Random Forest	~0.53	~13.03

🏆 Best Model

The interaction-enhanced linear model achieved the best performance, suggesting:

Relationships are partially linear
But benefit from feature interactions

## 📌 Key Insights
Retention rate is the strongest predictor of Latino completion
Higher SAT scores correlate with higher completion rates
Lower admission rates (more selective schools) → higher completion
Higher student–faculty ratios → lower completion rates
Financial variables have smaller but meaningful effects



# Contributors

