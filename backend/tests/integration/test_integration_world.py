import aiohttp
import pytest

from tests.service import service


@pytest.mark.asyncio
async def test_world_put_copy_delete(service):
    async with aiohttp.ClientSession(base_url=service.url) as client:
        resp = await client.get("/api/v0/test-login")
        assert resp.status == 200
        body = await resp.json()
        token = body["token"]

        headers = {"Authentication": token}

        resp = await client.post(
            "/api/v0/world",
            headers=headers,
            json={
                "name": "w1",
                "public": True,
                "description": "d",
                "data": {"initialState": {}},
            },
        )
        assert resp.status == 200
        world = await resp.json()
        world_id = world["id"]

        resp = await client.put(
            f"/api/v0/world/{world_id}", headers=headers, json={"name": "w1-updated"}
        )
        assert resp.status == 200
        updated = await resp.json()
        assert updated["name"] == "w1-updated"

        resp = await client.post(f"/api/v0/world/{world_id}/copy", headers=headers)
        assert resp.status == 200
        copied = await resp.json()
        assert copied["id"] != world_id

        resp = await client.delete(f"/api/v0/world/{world_id}", headers=headers)
        assert resp.status == 200
        deleted = await resp.json()
        assert deleted["deleted"] is True

        resp = await client.get(f"/api/v0/world/{world_id}")
        assert resp.status == 404
        body = await resp.json()
        assert body["code"] == "WorldNotFound"
