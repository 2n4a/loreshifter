using Microsoft.AspNetCore.DataProtection.Repositories;
using System.Xml.Linq;
using Microsoft.EntityFrameworkCore;

namespace Loreshifter.Data;


public class PostgresXmlRepository(IDbContextFactory<AppDbContext> contextFactory) : IXmlRepository
{
    public IReadOnlyCollection<XElement> GetAllElements()
    {
        using var context = contextFactory.CreateDbContext();

        var keys = context.DataProtectionKeys
            .AsNoTracking()
            .Select(k => k.Xml)
            .ToList();

        return keys
            .Select(XElement.Parse)
            .ToList()
            .AsReadOnly();
    }

    public void StoreElement(XElement element, string friendlyName)
    {
        using var context = contextFactory.CreateDbContext();

        var key = new DataProtectionKey
        {
            FriendlyName = friendlyName,
            Xml = element.ToString(SaveOptions.DisableFormatting),
            CreationTime = DateTime.UtcNow
        };

        context.DataProtectionKeys.Add(key);
        context.SaveChanges();
    }
}
