# Spideli Finance – Customer App Demo: English Narration Script

Video: `Spideli_Finance_Customer_Demo.mp4` (1920×1080, 30 fps, 8 min 23 s). Subtitles: burned in, plus a selectable English track and `Spideli_Finance_Customer_Demo.srt`.

**Presenter:** the narration is a computer-generated English voice (macOS "Samantha"). The video has **no human presenter**, and none is shown or implied; the opening card says so. To use a real presenter, record this script in a studio and lay it over the same screen recordings (the scene timings below are the edit points).

**Footage:** every app screen is a real screen recording of the Spideli customer app (debug build) running on an Android emulator, connected to a private local Firebase test environment with fictional customers (Amina Diallo, Jean Mbarga, Fatou Ndiaye) and test money. Admin steps (payouts, approvals) were performed with the QA environment's admin script, as the admin panel would.

| # | Start | Scene | On screen |
|---|---|---|---|
| 0 | 0:00 | About this demonstration | Title card |
| 1 | 0:13 | Introduction | Screen recording of the app |
| 2 | 0:37 | Finance dashboard | Screen recording of the app |
| 3 | 1:08 | Services and wallet history | Screen recording of the app |
| 4 | 1:38 | Withdraw to Mobile Money | Screen recording of the app |
| 5 | 2:10 | Send money to another customer | Screen recording of the app |
| 6 | 2:40 | Pay a bill | Screen recording of the app |
| 7 | 3:32 | Currency conversion | Screen recording of the app |
| 8 | 3:46 | Virtual card | Screen recording of the app |
| 9 | 4:24 | Collective savings | Screen recording of the app |
| 10 | 4:56 | Tontine | Screen recording of the app |
| 11 | 5:20 | Member loans | Screen recording of the app |
| 12 | 5:39 | Investments | Screen recording of the app |
| 13 | 5:54 | Insurance | Screen recording of the app |
| 14 | 6:29 | When things go wrong | Screen recording of the app |
| 15 | 6:56 | Firebase and data consistency | Live test-database view (ledger posting + integrity check) |
| 16 | 7:15 | A complete journey | Screen recording of the app |
| 17 | 7:53 | Summary and current limitations | Title card |

## Scene 0 · About this demonstration  (0:00)

> This demonstration shows the real Spideli customer app, running in a private test environment with fictional customers and test money.
>
> The narration voice is computer generated. There is no human presenter.

## Scene 1 · Introduction  (0:13)

On-screen points: One place for everyday money · Real app, test environment · Sample customer: Amina Diallo

> Welcome to this walkthrough of Spideli Finance, the money module of the Spideli customer app.
>
> We will follow Amina, a sample customer, as she uses her wallet, sends money, pays bills, saves with her family and her community, invests, and protects herself with insurance.
>
> Everything you see is the real app, connected to a private test environment with test money.

## Scene 2 · Finance dashboard  (0:37)

On-screen points: Available balance and other currencies · Privacy eye hides the amounts · Coming up, This month, Your money

> Spideli Finance opens on Amina's dashboard.
>
> At the top is her available balance in Central African francs, with her other currencies just below. The eye icon hides the amounts when someone is looking over her shoulder.
>
> The four round buttons are her everyday actions: add money, send, pay bills, and withdraw.
>
> Further down, Coming up reminds her of her next payment, This month compares money in and money out, and Your money summarizes her savings, investments, loans, tontines and insurance.

## Scene 3 · Services and wallet history  (1:08)

On-screen points: Services grouped by purpose · History grouped by day · Search, filters, transaction details

> The Services tab groups every finance service by what it helps you do: pay and send, save and invest, borrow and protect, and get help.
>
> The Wallet tab shows her full history, grouped by day.
>
> She can search by reference, filter by type, and open any transaction to see its details and copy its reference.

## Scene 4 · Withdraw to Mobile Money  (1:38)

On-screen points: Amount checked against the balance · Fee shown before confirming · Live status until paid out

> Now Amina withdraws money to Mobile Money.
>
> If she asks for more than she has, the app tells her straight away, and the Continue button stays disabled.
>
> For twenty thousand francs, the fee is calculated for her, and she sees exactly what she receives and what leaves her wallet.
>
> She chooses her saved Orange Money number and confirms. The request is now in progress.
>
> When Spideli's operations team pays it out, the page updates on its own and shows the payout reference.

## Scene 5 · Send money to another customer  (2:10)

On-screen points: Recipient name shown before paying · Free between customers · Money arrives instantly

> Sending money to another Spideli customer is instant.
>
> Amina enters Jean's email address. Before anything is paid, the app checks the account and shows his name, so she knows the money is going to the right person.
>
> Transfers between customers are free. She confirms, pays from her wallet, and the money is in Jean's wallet straight away.

## Scene 6 · Pay a bill  (2:40)

On-screen points: Account number checked before paying · Fee and total shown · Prepaid code on the receipt

> Paying a bill takes just a few taps. Amina chooses electricity and her provider.
>
> A meter number in the wrong format is caught before she pays.
>
> She pays fifteen thousand francs, and the payment is processing.
>
> Once the provider confirms, her prepaid electricity code appears on the receipt, with a button to copy it.

## Scene 7 · Currency conversion  (3:32)

On-screen points: Official rate and fee shown · Exact amount received · One wallet per currency

> Amina can also hold euros and US dollars.
>
> The converter uses the published rate, and shows the fee and the exact amount she will receive before she confirms.

## Scene 8 · Virtual card  (3:46)

On-screen points: Top up from the wallet · Freeze in one tap · Unfreezing needs her password

> Her virtual card can be topped up from her wallet, given spending limits, and frozen in one tap if she misplaces her phone.
>
> Unfreezing asks for her password, so nobody else can do it.

## Scene 9 · Collective savings  (4:24)

On-screen points: Shared goal with the family · Progress and projected date · Group withdrawals are checked

> With collective savings, Amina and her family save towards a shared goal, here a deposit for a house.
>
> Every member can add money. The app shows the progress and the projected completion date, and a withdrawal from a group goal becomes a request that Spideli checks against the group's rules.

## Scene 10 · Tontine  (4:56)

On-screen points: Same amount every cycle · One member receives the pot in turn · Who has paid, live

> A tontine is a traditional rotating savings group. Each member pays the same amount every cycle, and one member receives the whole pot in turn.
>
> Amina already received the first pot. Now it is Jean's turn, and she pays her contribution for the second cycle.
>
> The app shows who has paid, who receives the pot, and the full schedule.

## Scene 11 · Member loans  (5:20)

On-screen points: The group votes · Members fund the loan · Clear agreement and schedule

> Members of a group can also lend to each other. Jean asked his tontine for a loan, the members voted, Amina funded it, and Jean accepted the agreement.
>
> As a lender, Amina sees the terms, the repayment schedule, the repayments already made, and her share to collect.

## Scene 12 · Investments  (5:39)

On-screen points: Funds compared by risk and fees · Risks accepted and signed · Portfolio value and gains

> In Investments, Amina compares funds by risk and fees, and reads their key facts before investing.
>
> Her portfolio shows its value, what she invested, and her gains or losses.

## Scene 13 · Insurance  (5:54)

On-screen points: Instant estimate · Active policy and premiums · Claim followed to payment

> For insurance, Amina answers a few questions and gets an estimate straight away.
>
> Her family health policy is active, with its premium schedule.
>
> When her daughter needed care, she declared a claim in the app, answered the insurer's question, and the claim was paid into her wallet.

## Scene 14 · When things go wrong  (6:29)

On-screen points: Failed payout refunded automatically · Reason always shown · Never charged twice

> Things do not always go to plan, and the app is honest about it.
>
> When a payout cannot be made, the money goes back to the wallet automatically, and the reason is shown.
>
> If the connection is lost while paying, the app does not pretend: it says the payment is not confirmed. Trying again finishes it, and can never charge twice.

## Scene 15 · Firebase and data consistency  (6:56)

On-screen points: Every movement recorded as debit and credit · Balances match history to the franc · Customers see only their own records

> Behind the screens, every movement of money is recorded in Firebase as a debit and a matching credit.
>
> In this test environment, an independent check confirms that every balance matches its history, to the franc.
>
> Customers only ever see their own records: the security rules refuse everything else.

## Scene 16 · A complete journey  (7:15)

On-screen points: Open the module · Send money · Check the result in the history

> To finish, here is a complete journey in one go.
>
> Amina opens Spideli Finance, sends five thousand francs to Fatou, sees the confirmation, and finds the transfer at the top of her recent activity, with all its details.

## Scene 17 · Summary and current limitations  (7:53)

> To sum up, Spideli Finance gives customers one place to hold, send, save and grow their money, with clear confirmations, live statuses and a complete history.
>
> A few parts depend on partners that are not connected yet. Adding money by card or Mobile Money needs the payment provider's live account. Card issuing needs a card issuer. Two step verification by SMS needs to be enabled in Firebase. And the AI financial coach is not available yet.
>
> Thank you for watching.
