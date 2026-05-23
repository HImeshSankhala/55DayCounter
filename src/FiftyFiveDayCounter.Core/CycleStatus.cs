namespace FiftyFiveDayCounter.Core;

public static class CycleStatus
{
    public const string Active = "Active";
    public const string DueSoon = "Due Soon";
    public const string DueToday = "Due Today";
    public const string Overdue = "Overdue";
    public const string Completed = "Completed";
    public const string Canceled = "Canceled";

    public static readonly string[] All =
    [
        Active,
        DueSoon,
        DueToday,
        Overdue,
        Completed,
        Canceled
    ];
}
