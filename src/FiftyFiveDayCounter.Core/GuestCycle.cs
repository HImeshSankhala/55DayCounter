namespace FiftyFiveDayCounter.Core;

public sealed class GuestCycle
{
    public int Id { get; set; }
    public string GuestName { get; set; } = string.Empty;
    public string RoomNumber { get; set; } = string.Empty;
    public DateTime CheckInDate { get; set; } = DateTime.Today;
    public DateTime CheckOutDate { get; set; } = DateTime.Today.AddDays(54);
    public DateTime NotifyDate { get; set; } = DateTime.Today.AddDays(49);
    public string Status { get; set; } = CycleStatus.Active;
    public string Notes { get; set; } = string.Empty;
    public string LastNotifiedFor { get; set; } = string.Empty;
}
