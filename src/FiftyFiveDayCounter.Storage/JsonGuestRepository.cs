using System.Text.Json;
using System.Text.Json.Serialization;
using FiftyFiveDayCounter.Core;

namespace FiftyFiveDayCounter.Storage;

public sealed class JsonGuestRepository
{
    private const string MutexName = "DaysCounterDataLock";
    private readonly string _dataPath;
    private readonly JsonSerializerOptions _jsonOptions = new()
    {
        WriteIndented = true,
        PropertyNameCaseInsensitive = true
    };

    public JsonGuestRepository(string dataPath)
    {
        _dataPath = dataPath;
    }

    public string DataPath => _dataPath;

    public IReadOnlyList<GuestCycle> Load()
    {
        if (!File.Exists(_dataPath))
        {
            return [];
        }

        using var mutex = new Mutex(false, MutexName);
        if (!mutex.WaitOne(TimeSpan.FromSeconds(10)))
        {
            throw new IOException("The guest database is busy. Please try again.");
        }

        try
        {
            var json = File.ReadAllText(_dataPath);
            if (string.IsNullOrWhiteSpace(json))
            {
                return [];
            }

            using var document = JsonDocument.Parse(json);
            JsonElement guestElement;
            if (document.RootElement.ValueKind == JsonValueKind.Array)
            {
                guestElement = document.RootElement;
            }
            else if (document.RootElement.TryGetProperty("guests", out var guestsProperty))
            {
                guestElement = guestsProperty;
            }
            else
            {
                return [];
            }

            var guests = new List<GuestCycle>();
            foreach (var item in guestElement.EnumerateArray())
            {
                guests.Add(ReadGuest(item));
            }

            return guests;
        }
        finally
        {
            mutex.ReleaseMutex();
        }
    }

    public void Save(IEnumerable<GuestCycle> guests)
    {
        var directory = Path.GetDirectoryName(_dataPath);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }

        using var mutex = new Mutex(false, MutexName);
        if (!mutex.WaitOne(TimeSpan.FromSeconds(10)))
        {
            throw new IOException("The guest database is busy. Please try again.");
        }

        var tempPath = Path.Combine(directory ?? AppContext.BaseDirectory, $"guests.{Guid.NewGuid():N}.tmp");
        try
        {
            File.WriteAllText(tempPath, JsonSerializer.Serialize(guests, _jsonOptions));
            File.Copy(tempPath, _dataPath, overwrite: true);
        }
        finally
        {
            if (File.Exists(tempPath))
            {
                File.Delete(tempPath);
            }

            mutex.ReleaseMutex();
        }
    }

    private static GuestCycle ReadGuest(JsonElement item)
    {
        var checkIn = ReadDate(item, "CheckInDate", DateTime.Today);
        var checkOut = ReadDate(item, "CheckOutDate", CycleRules.GetCycleDates(checkIn).CheckOutDate);
        var notifyDate = ReadDate(item, "NotifyDate", checkOut.AddDays(-CycleRules.DefaultNotificationLeadDays));

        return new GuestCycle
        {
            Id = ReadInt(item, "Id"),
            GuestName = ReadString(item, "GuestName"),
            RoomNumber = ReadString(item, "RoomNumber"),
            CheckInDate = checkIn.Date,
            CheckOutDate = checkOut.Date,
            NotifyDate = notifyDate.Date,
            Status = ReadString(item, "Status", CycleStatus.Active),
            Notes = ReadString(item, "Notes")
        };
    }

    private static int ReadInt(JsonElement item, string propertyName)
    {
        if (!item.TryGetProperty(propertyName, out var property))
        {
            return 0;
        }

        return property.ValueKind switch
        {
            JsonValueKind.Number when property.TryGetInt32(out var value) => value,
            JsonValueKind.String when int.TryParse(property.GetString(), out var value) => value,
            _ => 0
        };
    }

    private static string ReadString(JsonElement item, string propertyName, string fallback = "")
    {
        if (!item.TryGetProperty(propertyName, out var property))
        {
            return fallback;
        }

        return property.ValueKind == JsonValueKind.String ? property.GetString() ?? fallback : fallback;
    }

    private static DateTime ReadDate(JsonElement item, string propertyName, DateTime fallback)
    {
        var value = ReadString(item, propertyName);
        if (string.IsNullOrWhiteSpace(value))
        {
            return fallback.Date;
        }

        return DateTime.TryParse(value, out var parsed) ? parsed.Date : fallback.Date;
    }
}
