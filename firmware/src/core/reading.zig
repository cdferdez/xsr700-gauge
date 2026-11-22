/// One measurement from any source, in metric units.
/// Sources produce these; only SignalStore turns them into display State.
pub const Reading = union(enum) {
    rpm: u16,
    speed_kmh: f32,
    coolant_c: i16,
    engine_error: u8,
    /// From a gear position sensor. null = the sensor reports no gear engaged.
    gear: ?u3,
    neutral: bool,
};
