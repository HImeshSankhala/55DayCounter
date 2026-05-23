namespace FiftyFiveDayCounter.Core;

public static class CycleRules
{
    public static CycleDates GetCycleDates(DateTime checkInDate)
    {
        var checkIn = checkInDate.Date;
        var checkOut = checkIn.AddDays(54);
        return new CycleDates(checkOut, checkOut.AddDays(-5));
    }

    public static string GetDisplayStatus(GuestCycle guest, DateTime today)
    {
        if (string.Equals(guest.Status, CycleStatus.Completed, StringComparison.OrdinalIgnoreCase))
        {
            return CycleStatus.Completed;
        }

        if (string.Equals(guest.Status, CycleStatus.Canceled, StringComparison.OrdinalIgnoreCase))
        {
            return CycleStatus.Canceled;
        }

        var daysLeft = (guest.CheckOutDate.Date - today.Date).Days;
        return daysLeft switch
        {
            < 0 => CycleStatus.Overdue,
            0 => CycleStatus.DueToday,
            <= 5 => CycleStatus.DueSoon,
            _ => CycleStatus.Active
        };
    }

    public static bool IsOperationalStatus(string status)
    {
        return status is CycleStatus.Active or CycleStatus.DueSoon or CycleStatus.DueToday or CycleStatus.Overdue;
    }

    public static bool IsTodayListEligible(GuestCycle guest, DateTime today)
    {
        var status = GetDisplayStatus(guest, today);
        if (status is CycleStatus.Completed or CycleStatus.Canceled)
        {
            return false;
        }

        return guest.CheckOutDate.Date <= today.Date.AddDays(5);
    }

    public static bool IsNotificationEligible(GuestCycle guest, DateTime today)
    {
        return IsTodayListEligible(guest, today);
    }

    public static string FormatDaysLeft(GuestCycle guest, DateTime today)
    {
        var status = GetDisplayStatus(guest, today);
        if (status is CycleStatus.Completed or CycleStatus.Canceled)
        {
            return string.Empty;
        }

        var daysLeft = (guest.CheckOutDate.Date - today.Date).Days;
        if (daysLeft == 0)
        {
            return "Due today";
        }

        if (daysLeft < 0)
        {
            return $"{Math.Abs(daysLeft)} day(s) overdue";
        }

        return $"{daysLeft} day(s) left";
    }

    public static GuestCycle CreateGuest(int id, string guestName, string roomNumber, DateTime checkInDate, string notes)
    {
        var dates = GetCycleDates(checkInDate);
        return new GuestCycle
        {
            Id = id,
            GuestName = guestName.Trim(),
            RoomNumber = roomNumber.Trim(),
            CheckInDate = checkInDate.Date,
            CheckOutDate = dates.CheckOutDate,
            NotifyDate = dates.NotifyDate,
            Status = CycleStatus.Active,
            Notes = notes.Trim(),
            LastNotifiedFor = string.Empty
        };
    }

    public static void ApplyEditableFields(GuestCycle guest, string guestName, string roomNumber, DateTime checkInDate, string notes)
    {
        var dates = GetCycleDates(checkInDate);
        guest.GuestName = guestName.Trim();
        guest.RoomNumber = roomNumber.Trim();
        guest.CheckInDate = checkInDate.Date;
        guest.CheckOutDate = dates.CheckOutDate;
        guest.NotifyDate = dates.NotifyDate;
        guest.Notes = notes.Trim();
        if (guest.Status is not CycleStatus.Completed and not CycleStatus.Canceled)
        {
            guest.Status = CycleStatus.Active;
        }

        guest.LastNotifiedFor = string.Empty;
    }

    public static GuestCycle? FindActiveRoomConflict(IEnumerable<GuestCycle> guests, string roomNumber, int excludeId, DateTime today)
    {
        var requestedRoom = roomNumber.Trim();
        return guests.FirstOrDefault(guest =>
            guest.Id != excludeId &&
            string.Equals(guest.RoomNumber.Trim(), requestedRoom, StringComparison.OrdinalIgnoreCase) &&
            IsOperationalStatus(GetDisplayStatus(guest, today)));
    }
}
