Path - C:\Users\18870\.gemini\antigravity\brain\e7268018-acb0-49da-8482-d08d3797b4f3


# RevenueCat Dashboard — Complete Setup Guide

> **Follow these steps exactly and you won't need to Google or watch any videos.**

---

## 📋 Overview: What You Need to Create

| Where | What |
|---|---|
| **Google Play Console** | 2 recurring subscriptions, 6 one-time in-app products |
| **RevenueCat Dashboard** | 2 entitlements, 1 offering with multiple packages |

---

## 💰 Multi-Year Pricing Strategy

Google Play limits auto-renewing subscriptions to a maximum of 1 year. To offer 2, 3, and 5-year plans, they must be created as **In-App Products (one-time purchases)**. 

Here is the pricing structure showing the original annual value vs the discounted price:

| Plan | Base Annual Value | 1 Year (10% off) | 2 Years (20% off) | 3 Years (25% off) | 5 Years (30% off) |
|---|---|---|---|---|---|
| **Pro** | ₹1,788/yr (₹149x12) | **₹1,599** | **₹2,399** (vs ₹2,999) | **₹2,999** (vs ₹3,999) | **₹3,499** (vs ₹4,999) |
| **Premium** | ₹3,588/yr (₹299x12)| **₹3,199** | **₹4,799** (vs ₹5,999) | **₹5,999** (vs ₹7,999)| **₹6,999** (vs ₹9,999)|

*(Note: Since RevenueCat treats one-time purchases as "Lifetime" by default, our app will include logic to verify the purchase date and automatically revoke access after the exact 2, 3, or 5-year period has passed.)*

---

## Part 1: Google Play Console — Create Products

### Step 1: Open Google Play Console
1. Go to [play.google.com/console](https://play.google.com/console)
2. Select your app: **Kaccha Pakka Khata**

### Step 2: Create Subscriptions (Monthly & 1-Year)
1. Go to **Monetize** → **Products** → **Subscriptions**
2. **Pro Monthly:**
   - Product ID: `pro_monthly`
   - Base plan: `pro-monthly-bp`, 1 Month, Auto-renewing, ₹149.
   - Offer: `pro-monthly-trial` (30-day free trial, "Never had any subscription")
3. **Pro 1-Year (Auto-renew):**
   - Product ID: `pro_yearly`
   - Base plan: `pro-yearly-bp`, 1 Year, Auto-renewing, ₹1,599.
   - Offer: `pro-yearly-trial` (30-day free trial, "Never had any subscription")
4. **Premium Monthly:**
   - Product ID: `premium_monthly`
   - Base plan: `premium-monthly-bp`, 1 Month, Auto-renewing, ₹299.
   - Offer: `premium-monthly-trial` (30-day free trial, "Never had any subscription")
5. **Premium 1-Year (Auto-renew):**
   - Product ID: `premium_yearly`
   - Base plan: `premium-yearly-bp`, 1 Year, Auto-renewing, ₹3,199.
   - Offer: `premium-yearly-trial` (30-day free trial, "Never had any subscription")

### Step 3: Create Multi-Year Products (2, 3, 5 Years)

⚠️ **CRITICAL: Multi-year purchases MUST be created as "One-time products", NOT "Subscriptions"!** Google Play subscriptions max out at 1 year.

1. Go to **Monetize** → **Products** → **One-time products** in the left sidebar.
2. For each product below, click **"Create product"** and fill in the details. Google recently updated their UI to include a "Purchase option" section for these.

#### 1. Pro - 2 Years
- **Product ID:** `pro_2_year`
- **Name:** Pro 2-Year Access
- **Description:** 2 full years of Pro access. Includes unlimited khatas, report history, and ad-free experience.
- **Purchase option ID:** `pro-2-year-purchase`
- **Purchase type:** Buy
- **Price:** ₹2,999
- **Add Discount Section:** 
  - **Offer ID:** `pro-2-year-off-20`
  - **Offer type:** Percentage → `20`
  - **End date and time:** Offer runs indefinitely
- Click **Save**, then click **Activate**.

#### 2. Pro - 3 Years
- **Product ID:** `pro_3_year`
- **Name:** Pro 3-Year Access
- **Description:** 3 full years of Pro access with an extra 25% discount.
- **Purchase option ID:** `pro-3-year-purchase`
- **Purchase type:** Buy
- **Price:** ₹3,999
- **Add Discount Section:** 
  - **Offer ID:** `pro-3-year-off-25`
  - **Offer type:** Percentage → `25`
  - **End date and time:** Offer runs indefinitely
- Click **Save**, then click **Activate**.

#### 3. Pro - 5 Years
- **Product ID:** `pro_5_year`
- **Name:** Pro 5-Year Access
- **Description:** 5 full years of Pro access with an extra 30% discount.
- **Purchase option ID:** `pro-5-year-purchase`
- **Purchase type:** Buy
- **Price:** ₹4,999
- **Add Discount Section:** 
  - **Offer ID:** `pro-5-year-off-30`
  - **Offer type:** Percentage → `30`
  - **End date and time:** Offer runs indefinitely
- Click **Save**, then click **Activate**.

#### 4. Premium - 2 Years
- **Product ID:** `premium_2_year`
- **Name:** Premium 2-Year Access
- **Description:** 2 full years of Premium access. Includes cloud backup and multi-device sync.
- **Purchase option ID:** `premium-2-year-purchase`
- **Purchase type:** Buy
- **Price:** ₹5,999
- **Add Discount Section:** 
  - **Offer ID:** `premium-2-year-off-20`
  - **Offer type:** Percentage → `20`
  - **End date and time:** Offer runs indefinitely
- Click **Save**, then click **Activate**.

#### 5. Premium - 3 Years
- **Product ID:** `premium_3_year`
- **Name:** Premium 3-Year Access
- **Description:** 3 full years of Premium access with an extra 25% discount.
- **Purchase option ID:** `premium-3-year-purchase`
- **Purchase type:** Buy
- **Price:** ₹7,999
- **Add Discount Section:** 
  - **Offer ID:** `premium-3-year-off-25`
  - **Offer type:** Percentage → `25`
  - **End date and time:** Offer runs indefinitely
- Click **Save**, then click **Activate**.

#### 6. Premium - 5 Years
- **Product ID:** `premium_5_year`
- **Name:** Premium 5-Year Access
- **Description:** 5 full years of Premium access with an extra 30% discount.
- **Purchase option ID:** `premium-5-year-purchase`
- **Purchase type:** Buy
- **Price:** ₹9,999
- **Add Discount Section:** 
  - **Offer ID:** `premium-5-year-off-30`
  - **Offer type:** Percentage → `30`
  - **End date and time:** Offer runs indefinitely
- Click **Save**, then click **Activate**.

*(Note: You cannot add a "Free Trial Offer" to In-App Products. Free trials only apply to the monthly/1-year subscriptions).*

---

## Part 1.5: Connect Google Play to RevenueCat

> **⚠️ Note about Supabase vs Google Cloud:**
> You mentioned using Supabase. That's perfectly fine—Supabase is your database. However, Google Play forces *everyone* to use Google Cloud Console strictly to generate API keys for billing. It has nothing to do with hosting your database; it's just Google's security checkpoint. RevenueCat needs this key to ask Google, "Did this user actually pay?"

### Step 1: Create a Service Account (Google Cloud)
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (name it something like "KPK Billing") or select an existing one.
3. Search for **"Google Play Android Developer API"** in the top search bar and click **Enable**.
4. Go to **IAM & Admin → Service Accounts**.
5. Click **Create Service Account** (Name: "revenuecat-billing"). Skip the optional steps and click **Done**.
6. Click on your new service account email, go to the **Keys** tab, click **Add Key → Create new key → JSON**. 
7. This downloads a `.json` file to your computer. Keep it safe.

### Step 2: Grant Access in Google Play Console
1. Go back to your [Google Play Console](https://play.google.com/console).
2. Go to **Users and permissions** (on the left menu).
3. Click **Invite new users**.
4. In the email field, paste your **Service Account email address** (e.g., `revenuecat-billing@kpk-notifications.iam.gserviceaccount.com`).
5. Go to the **Account Permissions** tab and select **Admin (all permissions)**. 
6. Click **Invite user**.

### Step 3: Add your Real App to RevenueCat
Right now, you have a "Test Store" app in RevenueCat. We need to replace it with your real Android app.
1. Go to [RevenueCat Dashboard](https://app.revenuecat.com) → **Project Settings** (gear icon top left) → **Apps**.
2. Click **+ New** and select **Play Store**.
3. **App name:** Kaccha Pakka Khata
4. **Package Name:** (Find this in your `android/app/build.gradle` file, likely `com.divyanshkumar.kacchapakkakhata` or similar).
5. **Service Account credentials JSON:** Open the `.json` file you downloaded in Step 1 with a text editor, copy everything inside it, and paste it here.
6. Click **Save Changes**.

*(You can now safely delete the old "Test Store" app from RevenueCat by going to its settings and deleting it).*

## Part 2: RevenueCat Dashboard — Configure Entitlements

### Step 0: Cleanup Old Lifetime Products
Since we are switching to multi-year plans, you must remove the old lifetime products:
1. **In Google Play Console:** Go to **Monetize** → **Products** → **In-app products**. Find `lifetime_pro` and `lifetime_premium` and **Deactivate** them.
2. **In RevenueCat:** Go to **Products** → **Products**, find `lifetime_pro` and `lifetime_premium`, and delete them.

### Step 1: Add New Google Play Products to RevenueCat
1. In the left sidebar: **Products** → **Products**
2. Click the **📥 Import** button to sync your newly created `pro_2_year`, `premium_5_year`, etc., products from Google Play.

### Step 2: Configure Entitlements
#### Entitlement 1: Kaccha Pakka Khata Pro
1. Go to **Products** → **Entitlements** → **"Kaccha Pakka Khata Pro"**
2. Click **"Attach Products"**
3. Attach ALL Pro and Premium products (because Premium users get Pro access too!):
   - `pro_monthly` & `premium_monthly`
   - `pro_yearly` & `premium_yearly`
   - `pro_2_year`, `pro_3_year`, `pro_5_year`
   - `premium_2_year`, `premium_3_year`, `premium_5_year`
4. Click **"Save"**

#### Entitlement 2: Kaccha Pakka Khata Premium
1. Go to **Products** → **Entitlements** → **"Kaccha Pakka Khata Premium"** (Create it if it doesn't exist, Identifier: `premium`)
2. Click **"Attach Products"**
3. Attach ONLY the Premium products:
   - `premium_monthly`
   - `premium_yearly`
   - `premium_2_year`, `premium_3_year`, `premium_5_year`
4. Click **"Save"**

### Step 3: Create an Offering & Packages
1. Go to **Products** → **Offerings** → click on **"Default"** (or create it).
2. Inside the Default offering, create **Packages**. You will need multiple packages if you want to show them all in the paywall:
   - **Package: pro_monthly** (Attach `pro_monthly`)
   - **Package: pro_yearly** (Attach `pro_yearly`)
   - **Package: pro_2_year** (Attach `pro_2_year`)
   - **Package: premium_monthly** (Attach `premium_monthly`)
   - ...and so on for the others you wish to display.

*(Note: We will configure the Flutter UI to read these exact packages, allowing users to toggle between Monthly, Yearly, 2-Year, etc.)*

---

## Part 3: Testing & Trial Info

### Important Note on Free Trials
As discussed, we are offering a **30-Day Free Trial** on all recurring subscriptions (`pro_monthly`, `pro_yearly`, `premium_monthly`, `premium_yearly`). 
* Make sure you configured the Free Trial offer in Google Play Console (Step 2) for **30 Days** instead of 14 Days.
* Free trials can only be applied to *recurring subscriptions*, NOT the 2, 3, or 5-year one-time purchases.

### Testing the Flow
1. Ensure your email is added under **Settings** → **License Testing** in Google Play Console.
2. Run the app on a real Android device (emulators cannot test Google Play billing).
3. Try to access a locked feature to trigger the paywall and verify the 30-day trial and discounted prices appear correctly.
