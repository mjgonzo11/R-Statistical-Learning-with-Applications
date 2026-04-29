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
* Elastic Net
🌲 Tree-Based Models
* Random Forest
* Boosting
* Bagging

## 📊 Model Performance
| Model |	R² |	RMSE |
* Linear Regression (baseline)	~0.48	~13.65
* Elastic Net	~0.48	~13.65
* Random Forest	~0.56	~12.62
* Bagging ~0.54 ~12.86
* Boosting ~0.53 ~12.95

🏆 Best Model

The Random Forest achieved the best performance, suggesting:

Relationships are partially linear
But benefit from feature interactions

## 📌 Key Insights
Across all five models, retention rate and institutional type (CNTLAFFI) emerged as the most consistent and dominant predictors of Hispanic completion rates — confirmed independently by both Random Forest and Boosting, two fundamentally different architectures.

SAT median was significant in linear regression, but ranked lower in tree models — challenging how selecting higher performing students is a primary driver of completion rates.

Financial variables like Student loans, Pell Grants, and avg. loan amount consistently ranked in a secondary tier — meaningful but not primary drivers.

Elastic Net and Linear Regression performed nearly identically, confirming no overfitting in the baseline model.

## Future works

* more variables, incorporate campus resources, programming, and local economic factors, admissions support, academic support  as predictors.
* Multi year data, Add data across multiple years to track trends over time and improve generalizability.
* Advanced methods, Test additional models that may outperform Random Forest; build an institutional risk-signaling tool.
* other demographics, Extend analysis to Black students (lowest completion), Asian students (high completion, lower enrollment), and other minorities.

# Contributors
Jesica Garcia, Martin Gonzalez, & Habib Barbour


