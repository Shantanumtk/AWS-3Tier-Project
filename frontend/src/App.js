import React, { useEffect, useState } from "react";
import {
  fetchUsers,
  createUser,
  updateUser,
  deleteUser,
} from "./api";

const emptyForm = {
  full_name: "",
  email: "",
  is_active: true,
};

function App() {
  const [users, setUsers] = useState([]);
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState(null);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState("");

  const load = async () => {
    setLoading(true);
    setErr("");
    try {
      const data = await fetchUsers();
      setUsers(data);
    } catch (e) {
      setErr(e.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingId) {
        await updateUser(editingId, form);
      } else {
        await createUser(form);
      }
      setForm(emptyForm);
      setEditingId(null);
      load();
    } catch (e) {
      setErr(e.message);
    }
  };

  const handleEdit = (u) => {
    setEditingId(u.id);
    setForm({
      full_name: u.full_name,
      email: u.email,
      is_active: u.is_active,
    });
  };

  const handleDelete = async (id) => {
    try {
      await deleteUser(id);
      load();
    } catch (e) {
      setErr(e.message);
    }
  };

  return (
    <div className="min-h-screen">
      <header className="bg-white shadow">
        <div className="max-w-6xl mx-auto px-4 py-4 flex items-center justify-between">
          <h1 className="text-xl font-bold text-slate-800">User Admin</h1>
          <span className="text-sm text-slate-500">React + FastAPI</span>
        </div>
      </header>

      <main className="max-w-6xl mx-auto px-4 py-6 flex gap-6">
        {/* Form */}
        <div className="w-1/3">
          <div className="bg-white rounded-xl shadow p-4">
            <h2 className="text-lg font-semibold mb-4">
              {editingId ? "Edit user" : "Create user"}
            </h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm mb-1">Full name</label>
                <input
                  type="text"
                  value={form.full_name}
                  onChange={(e) =>
                    setForm({ ...form, full_name: e.target.value })
                  }
                  className="w-full rounded-lg border-slate-200"
                  required
                />
              </div>
              <div>
                <label className="block text-sm mb-1">Email</label>
                <input
                  type="email"
                  value={form.email}
                  onChange={(e) =>
                    setForm({ ...form, email: e.target.value })
                  }
                  className="w-full rounded-lg border-slate-200"
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
                />
                <label htmlFor="is_active" className="text-sm">
                  Active
                </label>
              </div>
              <button
                type="submit"
                className="w-full bg-slate-800 text-white rounded-lg py-2 hover:bg-slate-700"
              >
                {editingId ? "Update" : "Create"}
              </button>
            </form>
          </div>
        </div>

        {/* Table */}
        <div className="w-2/3">
          <div className="bg-white rounded-xl shadow p-4">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold">Users</h2>
              <button
                onClick={load}
                className="text-sm text-slate-500 hover:text-slate-800"
              >
                Refresh
              </button>
            </div>
            {err && (
              <p className="text-sm text-red-600 mb-3 bg-red-50 p-2 rounded">
                {err}
              </p>
            )}
            {loading ? (
              <p className="text-sm text-slate-500">Loading...</p>
            ) : (
              <table className="min-w-full">
                <thead>
                  <tr className="text-left text-sm text-slate-500 border-b">
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
                      <td className="py-2 pr-3">{u.id}</td>
                      <td className="py-2 pr-3">{u.full_name}</td>
                      <td className="py-2 pr-3">{u.email}</td>
                      <td className="py-2 pr-3">
                        {u.is_active ? (
                          <span className="px-2 py-1 bg-green-100 text-green-600 rounded-full text-xs">
                            yes
                          </span>
                        ) : (
                          <span className="px-2 py-1 bg-red-100 text-red-600 rounded-full text-xs">
                            no
                          </span>
                        )}
                      </td>
                      <td className="py-2 text-right space-x-2">
                        <button
                          onClick={() => handleEdit(u)}
                          className="text-xs text-blue-600 hover:underline"
                        >
                          Edit
                        </button>
                        <button
                          onClick={() => handleDelete(u.id)}
                          className="text-xs text-red-600 hover:underline"
                        >
                          Del
                        </button>
                      </td>
                    </tr>
                  ))}
                  {users.length === 0 && (
                    <tr>
                      <td
                        colSpan={5}
                        className="py-4 text-center text-slate-400"
                      >
                        No users
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            )}
          </div>
        </div>
      </main>
    </div>
  );
}

export default App;
