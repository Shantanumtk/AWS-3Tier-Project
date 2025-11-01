// src/App.js
import React, { useEffect, useState } from "react";
import {
  fetchUsers,
  createUser,
  updateUser,
  deleteUser,
} from "./api";

const EMPTY_FORM = {
  full_name: "",
  email: "",
  is_active: true,
};

function App() {
  const [users, setUsers] = useState([]);
  const [form, setForm] = useState(EMPTY_FORM);
  const [editingId, setEditingId] = useState(null);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");
  const [ok, setOk] = useState("");

  const load = async () => {
    setLoading(true);
    setErr("");
    setOk("");
    try {
      const data = await fetchUsers();
      setUsers(data);
    } catch (e) {
      setErr(e.message || "Failed to load users");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    setErr("");
    setOk("");
    try {
      if (editingId) {
        await updateUser(editingId, form);
        setOk("User updated.");
      } else {
        await createUser(form);
        setOk("User created.");
      }
      setForm(EMPTY_FORM);
      setEditingId(null);
      load();
    } catch (e) {
      setErr(e.message || "Failed to save user");
    } finally {
      setSaving(false);
    }
  };

  const handleEdit = (u) => {
    setEditingId(u.id);
    setForm({
      full_name: u.full_name,
      email: u.email,
      is_active: u.is_active,
    });
    setOk("");
    setErr("");
  };

  const handleDelete = async (id) => {
    if (!window.confirm("Delete this user?")) return;
    setErr("");
    setOk("");
    try {
      await deleteUser(id);
      setOk("User deleted.");
      load();
    } catch (e) {
      setErr(e.message || "Failed to delete user");
    }
  };

  const handleCancel = () => {
    setEditingId(null);
    setForm(EMPTY_FORM);
    setErr("");
    setOk("");
  };

  return (
    <div className="min-h-screen bg-slate-100">
      {/* Top bar */}
      <header className="bg-slate-900 text-white shadow-sm">
        <div className="max-w-6xl mx-auto px-4 py-4 flex items-center justify-between">
          <div>
            <h1 className="text-xl font-semibold tracking-tight">
              User Admin
            </h1>
            <p className="text-xs text-slate-200">
              React (served from EC2) → /api → FastAPI behind internal ALB
            </p>
          </div>
          <span className="text-xs bg-slate-800 px-3 py-1 rounded-full">
            React + FastAPI
          </span>
        </div>
      </header>

      <main className="max-w-6xl mx-auto px-4 py-6 flex flex-col gap-6 lg:flex-row">
        {/* Left: Form */}
        <div className="lg:w-1/3">
          <div className="bg-white rounded-2xl shadow-sm border border-slate-100 p-5">
            <h2 className="text-lg font-semibold mb-4">
              {editingId ? "Edit user" : "Create user"}
            </h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">
                  Full name
                </label>
                <input
                  type="text"
                  value={form.full_name}
                  onChange={(e) =>
                    setForm({ ...form, full_name: e.target.value })
                  }
                  placeholder="Shantanu Mitkari"
                  className="w-full rounded-lg border-slate-200 focus:border-slate-400 focus:ring-slate-300"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">
                  Email
                </label>
                <input
                  type="email"
                  value={form.email}
                  onChange={(e) =>
                    setForm({ ...form, email: e.target.value })
                  }
                  placeholder="shantanu@example.com"
                  className="w-full rounded-lg border-slate-200 focus:border-slate-400 focus:ring-slate-300"
                  required
                />
              </div>
              <div className="flex items-center gap-2">
                <input
                  id="is_active"
                  type="checkbox"
                  checked={form.is_active}
                  onChange={(e) =>
                    setForm({ ...form, is_active: e.target.checked })
                  }
                  className="rounded border-slate-300"
                />
                <label htmlFor="is_active" className="text-sm text-slate-700">
                  Active
                </label>
              </div>
              <div className="flex gap-2">
                <button
                  type="submit"
                  disabled={saving}
                  className="flex-1 bg-slate-900 text-white rounded-lg py-2 text-sm font-medium hover:bg-slate-800 disabled:opacity-60"
                >
                  {saving ? "Saving..." : editingId ? "Update" : "Create"}
                </button>
                {editingId && (
                  <button
                    type="button"
                    onClick={handleCancel}
                    className="px-3 py-2 rounded-lg border text-sm text-slate-600 hover:bg-slate-50"
                  >
                    Cancel
                  </button>
                )}
              </div>
            </form>
          </div>
        </div>

        {/* Right: Table */}
        <div className="lg:w-2/3">
          <div className="bg-white rounded-2xl shadow-sm border border-slate-100 p-5">
            <div className="flex items-center justify-between mb-4">
              <div>
                <h2 className="text-lg font-semibold text-slate-900">
                  Users
                </h2>
                <p className="text-xs text-slate-500">
                  Data served via /api/users
                </p>
              </div>
              <button
                onClick={load}
                className="text-sm text-slate-500 hover:text-slate-900"
              >
                Refresh
              </button>
            </div>

            {err && (
              <p className="mb-3 text-sm text-red-700 bg-red-50 border border-red-100 rounded-lg px-3 py-2">
                {err}
              </p>
            )}

            {ok && (
              <p className="mb-3 text-sm text-emerald-700 bg-emerald-50 border border-emerald-100 rounded-lg px-3 py-2">
                {ok}
              </p>
            )}

            {loading ? (
              <p className="text-sm text-slate-500">Loading...</p>
            ) : users.length === 0 ? (
              <div className="h-32 flex flex-col items-center justify-center text-slate-400 text-sm bg-slate-50 rounded-xl">
                <p>No users found.</p>
                <p className="text-xs mt-1">
                  Create one from the form on the left.
                </p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="min-w-full text-sm">
                  <thead>
                    <tr className="text-left text-slate-500 border-b">
                      <th className="py-2 pr-3">ID</th>
                      <th className="py-2 pr-3">Name</th>
                      <th className="py-2 pr-3">Email</th>
                      <th className="py-2 pr-3">Active</th>
                      <th className="py-2 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {users.map((u) => (
                      <tr key={u.id} className="border-b last:border-none">
                        <td className="py-2 pr-3 text-slate-500">{u.id}</td>
                        <td className="py-2 pr-3">{u.full_name}</td>
                        <td className="py-2 pr-3">{u.email}</td>
                        <td className="py-2 pr-3">
                          {u.is_active ? (
                            <span className="px-2 py-1 rounded-full bg-emerald-100 text-emerald-700 text-xs font-medium">
                              yes
                            </span>
                          ) : (
                            <span className="px-2 py-1 rounded-full bg-red-100 text-red-700 text-xs font-medium">
                              no
                            </span>
                          )}
                        </td>
                        <td className="py-2 text-right space-x-2">
                          <button
                            onClick={() => handleEdit(u)}
                            className="text-xs text-slate-700 hover:text-slate-900"
                          >
                            Edit
                          </button>
                          <button
                            onClick={() => handleDelete(u.id)}
                            className="text-xs text-red-600 hover:text-red-700"
                          >
                            Del
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  );
}

export default App;
