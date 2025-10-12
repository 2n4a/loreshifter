using System.ComponentModel.DataAnnotations;

namespace Loreshifter.Models;

public class UpdateUserRequest
{
    [StringLength(100, ErrorMessage = "Name cannot be longer than 100 characters")]
    public string? Name { get; set; }
    
    // Email updates will be implemented later with email confirmation
    [EmailAddress(ErrorMessage = "Invalid email format")]
    public string? Email { get; set; }
}
