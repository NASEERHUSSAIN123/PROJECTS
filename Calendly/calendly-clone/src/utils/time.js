// Convert local date + time to UTC (for DB storage)
export function toUTC(date) {
  return new Date(date).toISOString();
}

// Convert UTC to user's local time (for display)
export function toLocal(utcDate) {
  return new Date(utcDate).toLocaleString();
}

// Format for input[type="date"]
export function formatDateInput(date) {
  if (!date) return "";
  const d = new Date(date);
  if (isNaN(d)) return "";
  return d.toISOString().split("T")[0];
}

// Get user's timezone
export function getUserTimezone() {
  return Intl.DateTimeFormat().resolvedOptions().timeZone;
}

// Convert time slot string to Date object
export function buildDateTime(selectedDate, timeString) {
  const [time, modifier] = timeString.split(" ");
  let [hours, minutes] = time.split(":");

  hours = parseInt(hours);

  if (modifier === "PM" && hours !== 12) hours += 12;
  if (modifier === "AM" && hours === 12) hours = 0;

  const date = new Date(selectedDate);
  date.setHours(hours);
  date.setMinutes(parseInt(minutes));
  date.setSeconds(0);

  return date;
}