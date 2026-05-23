using FiftyFiveDayCounter.Core;

var today = new DateTime(2026, 5, 23);

AssertEqual(new DateTime(2026, 5, 23), CycleRules.GetCycleDates(new DateTime(2026, 3, 30)).CheckOutDate, "55th day counts check-in as day 1");
AssertEqual(new DateTime(2026, 5, 18), CycleRules.GetCycleDates(new DateTime(2026, 3, 30)).NotifyDate, "notify date is 5 days before 55th day");

AssertStatus(CycleStatus.Active, today.AddDays(6));
AssertStatus(CycleStatus.DueSoon, today.AddDays(5));
AssertStatus(CycleStatus.DueToday, today);
AssertStatus(CycleStatus.Overdue, today.AddDays(-1));

var overdue = GuestWithCheckout(today.AddDays(-3));
var dueToday = GuestWithCheckout(today);
var dueSoon = GuestWithCheckout(today.AddDays(5));
var later = GuestWithCheckout(today.AddDays(6));
var completed = WithStatus(GuestWithCheckout(today), CycleStatus.Completed);

AssertTrue(CycleRules.IsTodayListEligible(overdue, today), "today list includes overdue guests");
AssertTrue(CycleRules.IsTodayListEligible(dueToday, today), "today list includes due today guests");
AssertTrue(CycleRules.IsTodayListEligible(dueSoon, today), "today list includes next 5 days");
AssertFalse(CycleRules.IsTodayListEligible(later, today), "today list excludes later guests");
AssertFalse(CycleRules.IsTodayListEligible(completed, today), "today list excludes completed guests");
AssertTrue(CycleRules.IsNotificationEligible(overdue, today), "notifications include overdue guests");
AssertTrue(CycleRules.IsNotificationEligible(dueToday, today), "notifications include due today guests");
AssertTrue(CycleRules.IsNotificationEligible(dueSoon, today), "notifications include next 5 days");
AssertFalse(CycleRules.IsNotificationEligible(later, today), "notifications exclude later guests");
AssertFalse(CycleRules.IsNotificationEligible(completed, today), "notifications exclude completed guests");

Console.WriteLine("Core rule tests passed.");

static GuestCycle GuestWithCheckout(DateTime checkoutDate)
{
    return new GuestCycle
    {
        Id = 1,
        GuestName = "Test",
        RoomNumber = "101",
        CheckInDate = checkoutDate.AddDays(-54),
        CheckOutDate = checkoutDate,
        NotifyDate = checkoutDate.AddDays(-5),
        Status = CycleStatus.Active
    };
}

static GuestCycle WithStatus(GuestCycle guest, string status)
{
    guest.Status = status;
    return guest;
}

static void AssertStatus(string expected, DateTime checkout)
{
    var guest = GuestWithCheckout(checkout);
    AssertEqual(expected, CycleRules.GetDisplayStatus(guest, new DateTime(2026, 5, 23)), $"status for checkout {checkout:yyyy-MM-dd}");
}

static void AssertEqual<T>(T expected, T actual, string message)
{
    if (!EqualityComparer<T>.Default.Equals(expected, actual))
    {
        throw new InvalidOperationException($"{message}: expected {expected}, got {actual}");
    }
}

static void AssertTrue(bool value, string message)
{
    if (!value)
    {
        throw new InvalidOperationException(message);
    }
}

static void AssertFalse(bool value, string message)
{
    if (value)
    {
        throw new InvalidOperationException(message);
    }
}
